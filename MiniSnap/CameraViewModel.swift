import AVFoundation
import Combine
import CoreGraphics
import Foundation
import Vision

final class CameraViewModel: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var recommendation: ExposureRecommendation?
    @Published private(set) var measurement: SceneMeasurement?
    @Published private(set) var statusText = "等待相机权限"
    @Published private(set) var automaticDistanceAvailable = false
    @Published private(set) var automaticDistance: Double?
    @Published var subjectDistance = 2.0

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "miniSnap.camera.session")
    private let analysisQueue = DispatchQueue(label: "miniSnap.camera.analysis")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private var isConfigured = false
    private var lastAnalysisTime = Date.distantPast
    private var latestFaceBounds: CGRect?

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

    private func configureSession() {
        session.beginConfiguration()

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

        guard let camera = makeBackCamera(),
              let input = try? AVCaptureDeviceInput(device: camera),
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
        // 按提案：优先选择单广角相机，避免多摄融合把变焦锁死为 1.0
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInLiDARDepthCamera,
            .builtInTripleCamera,
            .builtInDualWideCamera,
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

        let minZoom = camera.minAvailableVideoZoomFactor
        let maxZoom = camera.maxAvailableVideoZoomFactor

        let zoomFactor = Mini99Framing.videoZoomFactor(
            cameraHorizontalFieldOfViewDegrees: Double(fieldOfView),
            minimumZoomFactor: minZoom,
            maximumZoomFactor: maxZoom
        )

        // 调试输出：设置前的状态
        print("[CameraViewModel] FOV raw/corrected:", rawFOV, "/", correctedFOV, "-> using:", fieldOfView)
        print("[CameraViewModel] Device zoom range:", "min =", minZoom, "max =", maxZoom)
        print("[CameraViewModel] Computed zoomFactor:", zoomFactor)

        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            camera.videoZoomFactor = zoomFactor

            // 设置后再读回确认
            print("[CameraViewModel] Applied zoomFactor:", camera.videoZoomFactor)
        } catch {
            publishStatus("无法匹配 Mini 99 取景")
            print("[CameraViewModel] Failed to set zoom:", error.localizedDescription)
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

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)

        do {
            try handler.perform([request])
        } catch {
            publishStatus("人脸检测失败")
            return
        }

        guard let face = request.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
            latestFaceBounds = nil
            DispatchQueue.main.async { [weak self] in
                self?.measurement = nil
                self?.recommendation = nil
                self?.automaticDistance = nil
                self?.statusText = "未检测到人脸"
            }
            return
        }

        latestFaceBounds = face.boundingBox

        guard let measurement = LumaAnalyzer.measurement(
            pixelBuffer: pixelBuffer,
            faceBounds: face.boundingBox,
            distance: subjectDistance
        ) else {
            publishStatus("亮度分析失败")
            return
        }

        let recommendation = ExposureAdvisor.decide(measurement.input)

        DispatchQueue.main.async { [weak self] in
            self?.measurement = measurement
            self?.recommendation = recommendation
            self?.statusText = "建议已更新"
        }
    }

    private func publishStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusText = text
        }
    }

    private func publishAutomaticDistanceAvailability(_ isAvailable: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.automaticDistanceAvailable = isAvailable
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
            let latestFaceBounds,
            let distance = DepthDistanceEstimator.distanceMeters(from: depthData, faceBounds: latestFaceBounds)
        else {
            return
        }

        publishAutomaticDistance(distance)
    }
}
