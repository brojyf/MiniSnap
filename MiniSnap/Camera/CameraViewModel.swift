import AVFoundation
import Combine
import CoreGraphics
import CoreImage
import Foundation
import UIKit
import Vision

final class CameraViewModel: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var recommendation: ExposureRecommendation?
    @Published private(set) var measurement: SceneMeasurement?
    @Published private(set) var statusText = "等待相机权限"
    @Published private(set) var automaticDistanceAvailable = false
    @Published private(set) var automaticDistance: Double?
    @Published private(set) var saveStatusText: String?
    @Published private(set) var isSavingPhoto = false
    @Published var showsUnsupportedDeviceAlert = false
    @Published var manualDistancePreset: SubjectDistancePreset = .standard {
        didSet {
            if !automaticDistanceAvailable {
                subjectDistance = manualDistancePreset.distanceMeters
            }
        }
    }
    @Published var subjectDistance = 2.0

    let session = AVCaptureSession()

    // 与 LumaAnalyzer.centerSubjectRect 的 0.42 比例对齐，确保无主体时深度与亮度采样同一区域
    private static let centerSubjectVisionBounds = CGRect(x: 0.29, y: 0.29, width: 0.42, height: 0.42)

    private let sessionQueue = DispatchQueue(label: "miniSnap.camera.session")
    private let analysisQueue = DispatchQueue(label: "miniSnap.camera.analysis")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let imageContext = CIContext()
    private let watchPreviewTransmitter = WatchPreviewTransmitter()
    private let captureFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var isConfigured = false
    private var lastAnalysisTime = Date.distantPast
    private var latestSubjectBounds: CGRect?
    private var latestFrameImage: UIImage?

    override init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()
    }

    func requestAccessAndStart() {
        switch authorizationStatus {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.authorizationStatus = granted ? .authorized : .denied
                    granted ? self.start() : self.updateDeniedStatus()
                }
            }
        case .denied, .restricted:
            updateDeniedStatus()
        @unknown default:
            updateDeniedStatus()
        }
    }

    func start() {
        statusText = "正在启动相机"

        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.configureSession()
            }

            guard self.isConfigured else { return }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.statusText = "请将人脸放入画面"
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func saveFramedPhoto() {
        saveLatestFrame(includingRecommendation: false)
    }

    func saveRecommendationPhoto() {
        saveLatestFrame(includingRecommendation: true)
    }

    private func configureSession() {
        session.beginConfiguration()

        // 不让相机会话重置 App 的 AVAudioSession，否则会破坏音量键拍照依赖的会话配置
        session.automaticallyConfiguresApplicationAudioSession = false

        // 按提案：优先使用更宽松的预设，便于放开变焦范围
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        } else if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }

        guard let camera = makeBackCamera() else {
            session.commitConfiguration()
            publishUnsupportedDevice()
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            publishStatus("无法打开后置相机")
            return
        }

        configureDepthFormat(for: camera)
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            publishStatus("无法读取相机画面")
            return
        }

        session.addOutput(videoOutput)
        configureDepthOutputIfAvailable()
        session.commitConfiguration()

        // 设置预览匹配 Mini 99 视角（并打印调试信息）
        configureMini99FieldOfView(for: camera)

        isConfigured = true
    }

    private func makeBackCamera() -> AVCaptureDevice? {
        // 自动测距优先：LiDAR(Pro) > DualWide/Triple/Dual(普通版双摄)。仅单广角的老机型不支持。
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInLiDARDepthCamera,
            .builtInDualWideCamera,
            .builtInTripleCamera,
            .builtInDualCamera
        ]

        for deviceType in preferredTypes {
            if let device = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                return device
            }
        }

        return nil
    }

    private func configureDepthFormat(for camera: AVCaptureDevice) {
        guard let depthFormat = camera.activeFormat.supportedDepthDataFormats
            .filter({ CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32 })
            .max(by: { first, second in
                let firstDimensions = CMVideoFormatDescriptionGetDimensions(first.formatDescription)
                let secondDimensions = CMVideoFormatDescriptionGetDimensions(second.formatDescription)
                return firstDimensions.width * firstDimensions.height < secondDimensions.width * secondDimensions.height
            })
        else {
            return
        }

        do {
            try camera.lockForConfiguration()
            camera.activeDepthDataFormat = depthFormat
            camera.unlockForConfiguration()
        } catch {
            publishStatus("无法启用自动测距")
        }
    }

    private func configureMini99FieldOfView(for camera: AVCaptureDevice) {
        let correctedFOV = camera.activeFormat.geometricDistortionCorrectedVideoFieldOfView
        let rawFOV = camera.activeFormat.videoFieldOfView
        let fieldOfView = correctedFOV > 0 ? correctedFOV : rawFOV

        // 启用深度后，可用变焦范围会被深度交付约束收紧；
        // min/maxAvailableVideoZoomFactor 已动态反映此约束，直接使用即可。
        let minZoom = camera.minAvailableVideoZoomFactor
        let maxZoom = camera.maxAvailableVideoZoomFactor

        let zoomFactor = Mini99Framing.videoZoomFactor(
            cameraHorizontalFieldOfViewDegrees: Double(fieldOfView),
            minimumZoomFactor: minZoom,
            maximumZoomFactor: maxZoom
        )

        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            camera.videoZoomFactor = zoomFactor
        } catch {
            publishStatus("无法匹配 Mini 99 取景")
        }
    }

    private func configureDepthOutputIfAvailable() {
        guard session.canAddOutput(depthOutput) else {
            publishAutomaticDistanceAvailability(false)
            return
        }

        depthOutput.isFilteringEnabled = true
        depthOutput.setDelegate(self, callbackQueue: analysisQueue)
        session.addOutput(depthOutput)
        publishAutomaticDistanceAvailability(true)
    }

    private func analyze(pixelBuffer: CVPixelBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysisTime) >= 0.3 else {
            return
        }

        lastAnalysisTime = now

        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)

        do {
            try handler.perform([faceRequest, humanRequest])
        } catch {
            publishStatus("主体检测失败")
            return
        }

        let frameImage = image(from: pixelBuffer)
        let largestFace = faceRequest.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
        let largestHuman = humanRequest.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
        let subjectBounds: CGRect?
        let subjectDetection: SubjectDetection
        let nextStatusText: String

        if let largestFace {
            subjectBounds = largestFace.boundingBox
            subjectDetection = .face
            nextStatusText = "检测到人脸"
            latestSubjectBounds = largestFace.boundingBox
        } else if let largestHuman {
            subjectBounds = largestHuman.boundingBox
            subjectDetection = .person
            nextStatusText = "检测到人物，按人体估算"
            latestSubjectBounds = largestHuman.boundingBox
        } else {
            subjectBounds = nil
            subjectDetection = .centerSubject
            nextStatusText = "未检测到人物，按中心主体估算"
            latestSubjectBounds = Self.centerSubjectVisionBounds
        }

        guard let measurement = LumaAnalyzer.measurement(
            pixelBuffer: pixelBuffer,
            subjectBounds: subjectBounds,
            subjectDetection: subjectDetection,
            distance: subjectDistance
        ) else {
            publishStatus("亮度分析失败")
            return
        }

        let recommendation = ExposureAdvisor.decide(measurement.input)

        DispatchQueue.main.async { [weak self] in
            self?.latestFrameImage = frameImage
            self?.watchPreviewTransmitter.sendPreview(image: frameImage)
            self?.measurement = measurement
            self?.recommendation = recommendation
            self?.statusText = nextStatusText
        }
    }

    private func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = imageContext.createCGImage(image, from: image.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .right)
    }

    private func saveLatestFrame(includingRecommendation: Bool) {
        guard !isSavingPhoto else {
            return
        }

        guard let frameImage = latestFrameImage else {
            saveStatusText = "还没有可保存的画面"
            clearSaveStatusAfterDelay("还没有可保存的画面")
            return
        }

        let recommendation = recommendation

        // 提交保存的瞬间给一次触觉反馈，确认按键已识别（即便后续保存在后台进行）
        captureFeedback.impactOccurred()

        isSavingPhoto = true
        saveStatusText = "正在保存"

        // 渲染与编码均为重 CPU 操作，放到后台线程，避免冻结主线程影响连拍与 loading 动画
        Task.detached(priority: .userInitiated) {
            let finalStatus: String
            do {
                let image = includingRecommendation
                    ? PhotoExportRenderer.recommendationImage(photo: frameImage, recommendation: recommendation)
                    : PhotoExportRenderer.framedPhoto(photo: frameImage)

                try await PhotoLibrarySaver.save(image)
                finalStatus = includingRecommendation ? "已保存参数图" : "已保存相框照片"
            } catch {
                finalStatus = "保存失败：\(error.localizedDescription)"
            }

            await MainActor.run {
                self.saveStatusText = finalStatus
                self.isSavingPhoto = false
                self.clearSaveStatusAfterDelay(finalStatus)
            }
        }
    }

    private func clearSaveStatusAfterDelay(_ statusText: String) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)

            if saveStatusText == statusText, !isSavingPhoto {
                saveStatusText = nil
            }
        }
    }

    private func publishStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusText = text
        }
    }

    private func publishUnsupportedDevice() {
        DispatchQueue.main.async { [weak self] in
            self?.statusText = "本机型不支持自动测距"
            self?.showsUnsupportedDeviceAlert = true
        }
    }

    private func publishAutomaticDistanceAvailability(_ isAvailable: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.automaticDistanceAvailable = isAvailable
            if isAvailable == false {
                self?.subjectDistance = self?.manualDistancePreset.distanceMeters ?? 1.5
            }
        }
    }

    private func publishAutomaticDistance(_ distance: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.automaticDistance = distance
            self?.subjectDistance = distance
        }
    }

    private func updateDeniedStatus() {
        statusText = "需要相机权限才能分析画面"
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        analyze(pixelBuffer: pixelBuffer)
    }
}

extension CameraViewModel: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        guard
            let latestSubjectBounds,
            let distance = DepthDistanceEstimator.distanceMeters(from: depthData, subjectBounds: latestSubjectBounds)
        else {
            return
        }

        publishAutomaticDistance(distance)
    }
}
