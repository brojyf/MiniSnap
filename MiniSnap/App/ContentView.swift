import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraViewModel()
    private let previewRecommendation: ExposureRecommendation?

    init(previewRecommendation: ExposureRecommendation? = nil) {
        self.previewRecommendation = previewRecommendation
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                background

                VStack(spacing: 0) {
                    AppTitleView(recommendation: previewRecommendation ?? camera.recommendation)
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

    var body: some View {
        HStack {
            Text("MiniSnap")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
            Spacer()
            if let recommendation {
                HStack(spacing: 4) {
                    Image(systemName: "camera.aperture")
                    Text(recommendation.control.shootingMode.localizedName)
                        .lineLimit(1)
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            }
        }
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
