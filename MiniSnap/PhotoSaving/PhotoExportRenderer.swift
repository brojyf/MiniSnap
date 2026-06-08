import UIKit

enum PhotoExportRenderer {
    private static let filmColor = UIColor(white: 0.9, alpha: 1)
    private static let panelColor = UIColor(white: 0.95, alpha: 1)
    private static let tileColor = UIColor.black.withAlphaComponent(0.08)

    static func framedPhoto(photo: UIImage) -> UIImage {
        let filmSize = CGSize(width: 1080, height: 1720)
        let imageRect = CGRect(x: 80, y: 140, width: 920, height: 1240)
        let renderer = UIGraphicsImageRenderer(size: filmSize)

        return renderer.image { context in
            filmColor.setFill()
            context.fill(CGRect(origin: .zero, size: filmSize))

            draw(photo, in: imageRect)
        }
    }

    static func recommendationImage(photo: UIImage, recommendation: ExposureRecommendation?) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let imageRect = CGRect(x: 80, y: 120, width: 920, height: 1240)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            filmColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            draw(photo, in: imageRect)

            let panelRect = CGRect(x: 80, y: 1440, width: 920, height: 320)
            panelColor.setFill()
            UIBezierPath(roundedRect: panelRect, cornerRadius: 24).fill()

            guard let recommendation else {
                drawText("暂无推荐参数", in: panelRect.insetBy(dx: 40, dy: 132), size: 32, weight: .semibold, alignment: .center)
                return
            }

            let control = recommendation.control
            let items = [
                ("模式", control.shootingMode.localizedName),
                ("距离", control.focusMode.rangeText),
                ("曝光", control.ev.rawValue),
                ("闪光", control.flash.localizedName)
            ]

            let tileGap: CGFloat = 16
            let tileWidth = (panelRect.width - 80 - tileGap * 3) / 4
            let tileHeight: CGFloat = 126
            let tileY = panelRect.midY - tileHeight / 2

            for (index, item) in items.enumerated() {
                let tileRect = CGRect(
                    x: panelRect.minX + 40 + CGFloat(index) * (tileWidth + tileGap),
                    y: tileY,
                    width: tileWidth,
                    height: tileHeight
                )
                tileColor.setFill()
                UIBezierPath(roundedRect: tileRect, cornerRadius: 14).fill()
                drawText(item.0, in: CGRect(x: tileRect.minX + 18, y: tileRect.minY + 22, width: tileRect.width - 36, height: 30), size: 24, weight: .medium)
                drawText(item.1, in: CGRect(x: tileRect.minX + 18, y: tileRect.minY + 58, width: tileRect.width - 36, height: 44), size: 34, weight: .bold)
            }
        }
    }

    private static func draw(_ image: UIImage, in rect: CGRect) {
        guard let cgImage = image.cgImage else {
            return
        }

        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let sourceAspect = sourceSize.width / sourceSize.height
        let targetAspect = rect.width / rect.height
        let cropRect: CGRect

        if sourceAspect > targetAspect {
            let width = sourceSize.height * targetAspect
            cropRect = CGRect(x: (sourceSize.width - width) / 2, y: 0, width: width, height: sourceSize.height)
        } else {
            let height = sourceSize.width / targetAspect
            cropRect = CGRect(x: 0, y: (sourceSize.height - height) / 2, width: sourceSize.width, height: height)
        }

        guard let cropped = cgImage.cropping(to: cropRect) else {
            return
        }

        UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation).draw(in: rect)
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        size: CGFloat,
        weight: UIFont.Weight,
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]

        text.draw(in: rect, withAttributes: attributes)
    }
}
