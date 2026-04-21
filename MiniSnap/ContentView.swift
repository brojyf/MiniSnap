import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            background

            VStack(spacing: 0) {
                AppTitleView()
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            RecommendationPanel(
                recommendation: camera.recommendation,
                authorizationStatus: camera.authorizationStatus,
                statusText: camera.statusText,
                requestAccess: camera.requestAccessAndStart
            )
            .padding(.horizontal, InstaxMiniLayout.bottomPanelHorizontalPadding)
            .offset(y: InstaxMiniLayout.bottomPanelDownshift)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .task {
            camera.requestAccessAndStart()
        }
        .onDisappear {
            camera.stop()
        }
    }

    @ViewBuilder
    private var background: some View {
        if camera.authorizationStatus == .authorized {
            InstaxMiniCameraPreview(session: camera.session)
        } else {
            Color(red: 0.07, green: 0.08, blue: 0.08)
                .ignoresSafeArea()
        }
    }
}

private struct InstaxMiniCameraPreview: View {
    let session: AVCaptureSession

    var body: some View {
        GeometryReader { geometry in
            let imageFrame = InstaxMiniLayout.imageFrame(in: geometry.size)

            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.08)
                    .ignoresSafeArea()

                CameraPreview(session: session)
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .overlay(Color.black.opacity(0.08))
                    .position(x: imageFrame.midX, y: imageFrame.midY)

                InstaxMiniViewfinderOverlay()
            }
        }
        .ignoresSafeArea()
    }
}

private enum InstaxMiniLayout {
    static let bottomPanelHeight: CGFloat = 136
    static let bottomPanelHorizontalPadding: CGFloat = 10
    static let bottomPanelDownshift: CGFloat = 20
    static let filmPanelGap: CGFloat = 12

    static func imageFrame(in size: CGSize) -> CGRect {
        let horizontalInset = max(20, size.width * 0.055)
        let topReserved = max(64, size.height * 0.09)
        let bottomReserved = bottomPanelHeight - bottomPanelDownshift + filmPanelGap
        let availableFilmWidth = max(1, size.width - horizontalInset * 2)
        let availableFilmHeight = max(1, size.height - topReserved - bottomReserved)
        let scale = min(
            availableFilmWidth / CGFloat(Mini99Framing.filmShortSideMillimeters),
            availableFilmHeight / CGFloat(Mini99Framing.filmLongSideMillimeters)
        )
        let filmWidth = CGFloat(Mini99Framing.filmShortSideMillimeters) * scale
        let filmHeight = CGFloat(Mini99Framing.filmLongSideMillimeters) * scale
        let sideMargin = CGFloat(Mini99Framing.sideBorderMillimeters) * scale
        let topMargin = CGFloat(Mini99Framing.topBorderMillimeters) * scale
        let width = CGFloat(Mini99Framing.imageShortSideMillimeters) * scale
        let height = CGFloat(Mini99Framing.imageLongSideMillimeters) * scale
        let filmX = (size.width - filmWidth) / 2
        let filmY = topReserved + (availableFilmHeight - filmHeight) / 2
        let x = filmX + sideMargin
        let y = filmY + topMargin

        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func filmFrame(around imageFrame: CGRect) -> CGRect {
        let scale = imageFrame.height / CGFloat(Mini99Framing.imageLongSideMillimeters)
        let sideMargin = CGFloat(Mini99Framing.sideBorderMillimeters) * scale
        let topMargin = CGFloat(Mini99Framing.topBorderMillimeters) * scale
        let bottomMargin = CGFloat(Mini99Framing.bottomBorderMillimeters) * scale

        return CGRect(
            x: imageFrame.minX - sideMargin,
            y: imageFrame.minY - topMargin,
            width: imageFrame.width + sideMargin * 2,
            height: imageFrame.height + topMargin + bottomMargin
        )
    }
}

private struct InstaxMiniViewfinderOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let imageFrame = InstaxMiniLayout.imageFrame(in: geometry.size)
            let filmFrame = InstaxMiniLayout.filmFrame(around: imageFrame)

            ZStack {
                bottomPaperBorderFill(filmFrame: filmFrame, imageFrame: imageFrame)
                    .fill(Color.white.opacity(0.9))

                paperBorder(filmFrame: filmFrame, imageFrame: imageFrame)
                    .fill(Color.white.opacity(0.9), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                    .frame(width: filmFrame.width, height: filmFrame.height)
                    .position(x: filmFrame.midX, y: filmFrame.midY)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
            }
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func paperBorder(filmFrame: CGRect, imageFrame: CGRect) -> Path {
        Path { path in
            path.addRoundedRect(in: filmFrame, cornerSize: CGSize(width: 4, height: 4))
            path.addRoundedRect(in: imageFrame, cornerSize: CGSize(width: 2, height: 2))
        }
    }

    private func bottomPaperBorderFill(filmFrame: CGRect, imageFrame: CGRect) -> Path {
        Path { path in
            path.addRect(
                CGRect(
                    x: filmFrame.minX,
                    y: imageFrame.maxY - 1,
                    width: filmFrame.width,
                    height: filmFrame.maxY - imageFrame.maxY + 1
                )
            )
        }
    }
}

private struct AppTitleView: View {
    var body: some View {
        HStack {
            Text("MiniSnap")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
            Spacer()
        }
    }
}

private struct RecommendationPanel: View {
    let recommendation: ExposureRecommendation?
    let authorizationStatus: AVAuthorizationStatus
    let statusText: String
    let requestAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch authorizationStatus {
            case .authorized:
                if let recommendation {
                    ControlSummary(recommendation: recommendation)
                } else {
                    WaitingForFaceView(statusText: statusText)
                }
            case .notDetermined:
                PermissionContent(
                    title: "打开相机开始测光",
                    message: "需要相机画面来检测人脸并计算亮度。",
                    buttonTitle: "允许相机",
                    action: requestAccess
                )
            default:
                PermissionContent(
                    title: "相机权限未开启",
                    message: "请在系统设置中允许 MiniSnap 使用相机。",
                    buttonTitle: "重新检查",
                    action: requestAccess
                )
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .frame(height: InstaxMiniLayout.bottomPanelHeight, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct PermissionContent: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: action) {
                Label(buttonTitle, systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct ControlSummary: View {
    let recommendation: ExposureRecommendation

    var body: some View {
        HStack(spacing: 8) {
            SummaryTile(title: "模式", value: recommendation.control.shootingMode.localizedName, systemImage: "camera.aperture")
            SummaryTile(
                title: "距离",
                value: recommendation.control.focusMode.rangeText,
                systemImage: "scope"
            )
            SummaryTile(
                title: "曝光",
                value: recommendation.control.ev.rawValue,
                systemImage: "plusminus"
            )
            SummaryTile(
                title: "闪光",
                value: recommendation.control.flash.localizedName,
                systemImage: "bolt.fill"
            )
        }
        .frame(maxHeight: .infinity)
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 66, maxHeight: 66, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WaitingForFaceView: View {
    let statusText: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "face.dashed")
                .font(.title2)
            Text("对准人脸")
                .font(.headline.weight(.semibold))
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
