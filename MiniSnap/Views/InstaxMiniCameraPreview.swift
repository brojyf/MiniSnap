import AVFoundation
import SwiftUI

struct InstaxMiniCameraPreview: View {
    let session: AVCaptureSession
    var showsCameraPreview = true

    var body: some View {
        GeometryReader { geometry in
            let imageFrame = InstaxMiniLayout.imageFrame(in: geometry.size)

            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.08)
                    .ignoresSafeArea()

                previewContent
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .overlay(Color.black.opacity(0.08))
                    .position(x: imageFrame.midX, y: imageFrame.midY)

                InstaxMiniViewfinderOverlay()
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var previewContent: some View {
        if showsCameraPreview {
            CameraPreview(session: session)
        } else {
            Color.black
        }
    }
}

enum InstaxMiniLayout {
    static let bottomPanelHeight: CGFloat = 140
    static let bottomPanelPadding: CGFloat = 11
    static let bottomPanelCornerRadius: CGFloat = 43
    static let bottomPanelDownshift: CGFloat = 20
    static let filmPanelGap: CGFloat = 12
    static let paperColor = Color(white: 0.9)
    static let bottomPaperColor = Color.white
    static let paperStrokeColor = Color(white: 0.96)
    static let imageStrokeColor = Color(uiColor: PhotoExportRenderer.imageStrokeColor)

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

struct InstaxMiniViewfinderOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let imageFrame = InstaxMiniLayout.imageFrame(in: geometry.size)
            let filmFrame = InstaxMiniLayout.filmFrame(around: imageFrame)

            ZStack {
                paperBorder(filmFrame: filmFrame, imageFrame: imageFrame)
                    .fill(InstaxMiniLayout.paperColor, style: FillStyle(eoFill: true))

                bottomPaperBorderFill(filmFrame: filmFrame, imageFrame: imageFrame)
                    .fill(InstaxMiniLayout.bottomPaperColor)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(InstaxMiniLayout.paperStrokeColor, lineWidth: 1.5)
                    .frame(width: filmFrame.width, height: filmFrame.height)
                    .position(x: filmFrame.midX, y: filmFrame.midY)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(InstaxMiniLayout.imageStrokeColor, lineWidth: 1)
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
                    y: imageFrame.maxY,
                    width: filmFrame.width,
                    height: filmFrame.maxY - imageFrame.maxY
                )
            )
        }
    }
}
