import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraViewModel()
    @StateObject private var motionRotation = MotionRotationObserver()
    private let previewRecommendation: ExposureRecommendation?

    init(previewRecommendation: ExposureRecommendation? = nil) {
        self.previewRecommendation = previewRecommendation
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                background

                VStack(spacing: 0) {
                    AppTitleView(
                        recommendation: previewRecommendation ?? camera.recommendation,
                        rotationAngle: motionRotation.rotationAngle
                    )
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                RecommendationPanel(
                    recommendation: previewRecommendation ?? camera.recommendation,
                    subjectDetection: previewRecommendation == nil ? camera.measurement?.input.subjectDetection ?? .centerSubject : .face,
                    authorizationStatus: previewRecommendation == nil ? camera.authorizationStatus : .authorized,
                    statusText: camera.statusText,
                    rotationAngle: motionRotation.rotationAngle,
                    requestAccess: camera.requestAccessAndStart
                )
                .padding(.horizontal, InstaxMiniLayout.bottomPanelPadding)
                .offset(y: max(0, geometry.safeAreaInsets.bottom - InstaxMiniLayout.bottomPanelPadding))
                .ignoresSafeArea(.container, edges: .bottom)

                if camera.isSavingPhoto || camera.saveStatusText != nil {
                    SaveFeedbackOverlay(
                        saveStatusText: camera.saveStatusText,
                        isSavingPhoto: camera.isSavingPhoto
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
        }
        .animation(.snappy(duration: 0.28), value: camera.isSavingPhoto)
        .animation(.snappy(duration: 0.28), value: camera.saveStatusText)
        .task {
            motionRotation.start()

            if previewRecommendation == nil {
                camera.requestAccessAndStart()
            }
        }
        .overlay {
            VolumeButtonCaptureView(
                onVolumeDown: camera.saveFramedPhoto,
                onVolumeUp: camera.saveRecommendationPhoto
            )
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
        .onDisappear {
            motionRotation.stop()

            if previewRecommendation == nil {
                camera.stop()
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if previewRecommendation != nil {
            Color(red: 0.07, green: 0.08, blue: 0.08)
                .ignoresSafeArea()
        } else {
            InstaxMiniCameraPreview(
                session: camera.session,
                showsCameraPreview: camera.authorizationStatus == .authorized
            )
        }
    }
}

private struct AppTitleView: View {
    let recommendation: ExposureRecommendation?
    let rotationAngle: Angle

    var body: some View {
        HStack {
            Text("MiniSnap")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
            Spacer()
            if let recommendation {
                AdaptiveModeLabel(
                    title: recommendation.control.shootingMode.localizedName,
                    rotationAngle: rotationAngle
                )
            }
        }
    }
}

private struct AdaptiveModeLabel: View {
    let title: String
    let rotationAngle: Angle

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "camera.aperture")
                .rotationEffect(rotationAngle)
            HStack(spacing: 0) {
                ForEach(Array(orientedCharacters.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .rotationEffect(rotationAngle)
                }
            }
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.34), value: rotationAngle)
    }

    private var orientedCharacters: [Character] {
        let characters = Array(title)
        return rotationAngle.degrees > 0 ? characters.reversed() : characters
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(previewRecommendation: previewRecommendation)
    }

    private static var previewRecommendation: ExposureRecommendation {
        ExposureRecommendation(
            control: ExposureControl(
                shootingMode: .normal,
                focusMode: .standard,
                ev: .n,
                flash: .off
            ),
            confidence: 0.86,
            reasons: ["预览用 mock 参数"],
            warnings: []
        )
    }
}
