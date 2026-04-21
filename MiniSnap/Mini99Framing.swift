import CoreGraphics
import Foundation

enum Mini99Framing {
    static let imageLongSideMillimeters = 62.0
    static let imageShortSideMillimeters = 46.0
    static let filmLongSideMillimeters = 86.0
    static let filmShortSideMillimeters = 54.0
    static let topBorderMillimeters = 7.0
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
        // 调试：输入与设备变焦范围
        print("[Mini99Framing] Input FOV(deg):", cameraHorizontalFieldOfViewDegrees)
        print("[Mini99Framing] Device zoom range:", "min =", minimumZoomFactor, "max =", maximumZoomFactor)

        guard cameraHorizontalFieldOfViewDegrees > 0 else {
            print("[Mini99Framing] Invalid FOV. Using minimum zoom factor:", minimumZoomFactor)
            return minimumZoomFactor
        }

        // 由水平 FOV 反推当前“全画幅等效焦距”
        let halfAngle = degreesToRadians(cameraHorizontalFieldOfViewDegrees / 2)
        let currentEquivalentFocal = fullFrameLandscapeWidthMillimeters / (2 * tan(halfAngle))

        guard currentEquivalentFocal.isFinite, currentEquivalentFocal > 0 else {
            print("[Mini99Framing] Invalid equivalent focal length. Using minimum zoom factor:", minimumZoomFactor)
            return minimumZoomFactor
        }

        // 目标等效焦距：35mm
        let targetEquivalent = targetFullFrameEquivalentFocalLengthMillimeters

        // 计算未裁剪的匹配倍数
        let rawMatching = targetEquivalent / currentEquivalentFocal

        // 调试输出
        print("[Mini99Framing] Current equivalent focal length(mm):", String(format: "%.3f", currentEquivalentFocal))
        print("[Mini99Framing] Target equivalent focal length(mm):", String(format: "%.3f", targetEquivalent))
        print("[Mini99Framing] Raw matching zoom:", String(format: "%.3f", rawMatching))

        // 裁剪到设备允许范围
        let clamped = min(max(CGFloat(rawMatching), minimumZoomFactor), maximumZoomFactor)
        print("[Mini99Framing] Final zoom after clamp:", String(format: "%.3f", clamped))

        return clamped
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}
