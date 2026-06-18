import CoreGraphics
import Foundation

enum Mini99Framing {
    static let imageLongSideMillimeters = 62.0
    static let imageShortSideMillimeters = 46.0
    static let filmLongSideMillimeters = 86.0
    static let filmShortSideMillimeters = 54.0
    static let topBorderMillimeters = 6.0
    static let focalLengthMillimeters = 60.0
    // Mini 99's 60mm lens on instax mini is commonly framed as about a 35mm full-frame lens.
    static let targetFullFrameEquivalentFocalLengthMillimeters = 35.0
    private static let fullFrameLandscapeWidthMillimeters = 36.0

    static var sideBorderMillimeters: Double {
        (filmShortSideMillimeters - imageShortSideMillimeters) / 2
    }

    static var bottomBorderMillimeters: Double {
        filmLongSideMillimeters - imageLongSideMillimeters - topBorderMillimeters
    }

    static var landscapeHorizontalFieldOfViewDegrees: Double {
        radiansToDegrees(2 * atan(imageLongSideMillimeters / (2 * focalLengthMillimeters)))
    }

    static var portraitHorizontalFieldOfViewDegrees: Double {
        radiansToDegrees(2 * atan(imageShortSideMillimeters / (2 * focalLengthMillimeters)))
    }

    static var portraitImageAspectRatio: CGFloat {
        CGFloat(imageShortSideMillimeters / imageLongSideMillimeters)
    }

    static var landscapeImageAspectRatio: CGFloat {
        CGFloat(imageLongSideMillimeters / imageShortSideMillimeters)
    }

    static var portraitFilmAspectRatio: CGFloat {
        CGFloat(filmShortSideMillimeters / filmLongSideMillimeters)
    }

    static func videoZoomFactor(
        cameraHorizontalFieldOfViewDegrees: Double,
        minimumZoomFactor: CGFloat,
        maximumZoomFactor: CGFloat
    ) -> CGFloat {
        guard cameraHorizontalFieldOfViewDegrees > 0 else {
            return minimumZoomFactor
        }

        // 由水平 FOV 反推当前“全画幅等效焦距”
        let halfAngle = degreesToRadians(cameraHorizontalFieldOfViewDegrees / 2)
        let currentEquivalentFocal = fullFrameLandscapeWidthMillimeters / (2 * tan(halfAngle))

        guard currentEquivalentFocal.isFinite, currentEquivalentFocal > 0 else {
            return minimumZoomFactor
        }

        // 目标等效焦距：35mm
        let targetEquivalent = targetFullFrameEquivalentFocalLengthMillimeters

        // 计算未裁剪的匹配倍数
        let rawMatching = targetEquivalent / currentEquivalentFocal

        // 裁剪到设备允许范围
        return min(max(CGFloat(rawMatching), minimumZoomFactor), maximumZoomFactor)
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}
