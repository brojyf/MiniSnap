import CoreGraphics
import UIKit
import XCTest
@testable import MiniSnap

final class ExposureAdvisorTests: XCTestCase {
    @MainActor
    func testMini99FramingUsesOfficialPortraitAndLandscapeFieldOfView() {
        XCTAssertEqual(Mini99Framing.landscapeHorizontalFieldOfViewDegrees, 54.64, accuracy: 0.1)
        XCTAssertEqual(Mini99Framing.portraitHorizontalFieldOfViewDegrees, 41.98, accuracy: 0.1)
        XCTAssertEqual(Mini99Framing.targetFullFrameEquivalentFocalLengthMillimeters, 35.0, accuracy: 0.01)
    }

    @MainActor
    func testInstaxMiniFramingUsesOfficialFilmAndImageRatio() {
        XCTAssertEqual(Mini99Framing.portraitFilmAspectRatio, CGFloat(54.0 / 86.0), accuracy: 0.001)
        XCTAssertEqual(Mini99Framing.portraitImageAspectRatio, CGFloat(46.0 / 62.0), accuracy: 0.001)
    }

    @MainActor
    func testInstaxMiniBottomBorderIsWiderWithoutChangingFilmSize() {
        XCTAssertEqual(Mini99Framing.sideBorderMillimeters, 4.0, accuracy: 0.001)
        XCTAssertEqual(Mini99Framing.topBorderMillimeters + Mini99Framing.bottomBorderMillimeters, 24.0, accuracy: 0.001)
        XCTAssertGreaterThan(Mini99Framing.bottomBorderMillimeters, Mini99Framing.topBorderMillimeters)
    }

    @MainActor
    func testSavedFramedPhotoUsesLightGrayFilmBorder() {
        let image = PhotoExportRenderer.framedPhoto(photo: solidImage(color: .red))
        let borderColor = sampledColor(in: image, at: CGPoint(x: 68, y: 68))

        XCTAssertEqual(image.size, CGSize(width: 1176, height: 1816))
        XCTAssertEqual(borderColor.red, 0.9, accuracy: 0.02)
        XCTAssertEqual(borderColor.green, 0.9, accuracy: 0.02)
        XCTAssertEqual(borderColor.blue, 0.9, accuracy: 0.02)
    }

    @MainActor
    func testSavedFramedPhotoUsesWhiteBottomBorder() {
        let image = PhotoExportRenderer.framedPhoto(photo: solidImage(color: .red))
        let borderColor = sampledColor(in: image, at: CGPoint(x: 68, y: 1548))

        XCTAssertEqual(borderColor.red, 1.0, accuracy: 0.02)
        XCTAssertEqual(borderColor.green, 1.0, accuracy: 0.02)
        XCTAssertEqual(borderColor.blue, 1.0, accuracy: 0.02)
    }

    @MainActor
    func testSavedFramedPhotoAddsSubtleOuterShadow() {
        let image = PhotoExportRenderer.framedPhoto(photo: solidImage(color: .red))
        let shadowColor = sampledColor(in: image, at: CGPoint(x: 32, y: 900))

        XCTAssertLessThan(shadowColor.red, 0.99)
        XCTAssertLessThan(shadowColor.green, 0.99)
        XCTAssertLessThan(shadowColor.blue, 0.99)
    }

    @MainActor
    func testSavedFramedPhotoStrokesImageWithThinBlackBorder() {
        let image = PhotoExportRenderer.framedPhoto(photo: solidImage(color: .red))
        let strokeColor = sampledColor(in: image, at: CGPoint(x: 129, y: 700))

        XCTAssertEqual(strokeColor.red, 0.2, accuracy: 0.04)
        XCTAssertLessThan(strokeColor.green, 0.05)
        XCTAssertLessThan(strokeColor.blue, 0.05)
    }

    @MainActor
    func testSavedRecommendationImageUsesLightGrayFilmBorder() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.54,
                sceneLuma: 0.52,
                highlightRatio: 0.04,
                faceAreaRatio: 0.07,
                distance: 1.5
            )
        )
        let image = PhotoExportRenderer.recommendationImage(photo: solidImage(color: .red), recommendation: recommendation)
        let borderColor = sampledColor(in: image, at: CGPoint(x: 20, y: 20))

        XCTAssertEqual(image.size, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(borderColor.red, 0.9, accuracy: 0.02)
        XCTAssertEqual(borderColor.green, 0.9, accuracy: 0.02)
        XCTAssertEqual(borderColor.blue, 0.9, accuracy: 0.02)
    }

    @MainActor
    func testMini99FramingZoomsPortraitPreviewTowardMini99View() {
        let zoomFactor = Mini99Framing.videoZoomFactor(
            cameraHorizontalFieldOfViewDegrees: 70,
            minimumZoomFactor: 1,
            maximumZoomFactor: 5
        )

        XCTAssertEqual(zoomFactor, 1.36, accuracy: 0.02)
    }

    @MainActor
    func testMini99FramingDoesNotZoomWhenCameraIsAlreadyNarrower() {
        let zoomFactor = Mini99Framing.videoZoomFactor(
            cameraHorizontalFieldOfViewDegrees: 45,
            minimumZoomFactor: 1,
            maximumZoomFactor: 5
        )

        XCTAssertEqual(zoomFactor, 1)
    }

    @MainActor
    func testBacklitBrightSceneUsesDMinusAndFillFlash() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.34,
                sceneLuma: 0.72,
                highlightRatio: 0.18,
                faceAreaRatio: 0.08,
                distance: 1.8
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .normal, focusMode: .standard, ev: .dMinus, flash: .fill))
        XCTAssertTrue(recommendation.reasons.contains("检测到逆光"))
    }

    @MainActor
    func testLowLightBeyondFlashRangeUsesIndoorLOffAndWarns() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.24,
                sceneLuma: 0.18,
                highlightRatio: 0.02,
                faceAreaRatio: 0.06,
                distance: 3.2
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .indoor, focusMode: .landscape, ev: .l, flash: .off))
        XCTAssertTrue(recommendation.warnings.contains("超过 2.7 米，闪光可能无效"))
    }

    @MainActor
    func testLowLightWithinFlashRangeUsesIndoorFillFlash() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.24,
                sceneLuma: 0.18,
                highlightRatio: 0.02,
                faceAreaRatio: 0.06,
                distance: 1.6
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .indoor, focusMode: .standard, ev: .l, flash: .fill))
        XCTAssertTrue(recommendation.reasons.contains("室内模式可提亮暗处背景"))
    }

    @MainActor
    func testVeryLowLightBeyondFlashRangeUsesBulbAndWarnsAboutSupport() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.16,
                sceneLuma: 0.08,
                highlightRatio: 0.01,
                faceAreaRatio: 0.04,
                distance: 3.4
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .bulb, focusMode: .landscape, ev: .l, flash: .off))
        XCTAssertTrue(recommendation.warnings.contains("B 门需要桌面或三脚架稳定相机"))
    }

    @MainActor
    func testCloseSubjectUsesMacroFocusMode() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.5,
                sceneLuma: 0.5,
                highlightRatio: 0.03,
                faceAreaRatio: 0.14,
                distance: 0.45
            )
        )

        XCTAssertEqual(recommendation.control.focusMode, .macro)
        XCTAssertEqual(recommendation.control.focusMode.rangeText, "0.3-0.6")
    }

    @MainActor
    func testTooCloseSubjectWarnsAboutMinimumFocusDistance() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.5,
                sceneLuma: 0.5,
                highlightRatio: 0.03,
                faceAreaRatio: 0.2,
                distance: 0.24
            )
        )

        XCTAssertEqual(recommendation.control.focusMode, .macro)
        XCTAssertTrue(recommendation.warnings.contains("低于 0.3 米，Mini 99 可能无法合焦"))
    }

    @MainActor
    func testBalancedSceneKeepsManualFlashOff() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.54,
                sceneLuma: 0.52,
                highlightRatio: 0.04,
                faceAreaRatio: 0.07,
                distance: 1.5
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .normal, focusMode: .standard, ev: .n, flash: .off))
    }

    @MainActor
    func testCloseShadowedSubjectUsesFillFlashBeforeExposureLift() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.42,
                sceneLuma: 0.52,
                highlightRatio: 0.08,
                faceAreaRatio: 0.07,
                distance: 1.2
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .normal, focusMode: .standard, ev: .n, flash: .fill))
        XCTAssertTrue(recommendation.reasons.contains("Fill 闪光可补近处阴影并保留背景曝光"))
    }

    @MainActor
    func testNoFaceUsesCenterSubjectLanguageAndLowerConfidence() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.5,
                sceneLuma: 0.5,
                highlightRatio: 0.03,
                faceAreaRatio: 0.0,
                distance: 2.0,
                hasFace: false
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .normal, focusMode: .standard, ev: .n, flash: .off))
        XCTAssertTrue(recommendation.reasons.contains("画面中心主体与背景亮度平衡"))
        XCTAssertLessThan(recommendation.confidence, 0.8)
    }

    @MainActor
    func testNoFaceBacklitUsesCenterSubjectLanguage() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.34,
                sceneLuma: 0.72,
                highlightRatio: 0.18,
                faceAreaRatio: 0.0,
                distance: 1.5,
                hasFace: false
            )
        )

        XCTAssertEqual(recommendation.control.flash, .fill)
        XCTAssertTrue(recommendation.reasons.contains("画面中心主体亮度低于背景"))
    }

    @MainActor
    func testVeryLowLightTooCloseDoesNotRecommendBulb() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.1,
                sceneLuma: 0.08,
                highlightRatio: 0.01,
                faceAreaRatio: 0.18,
                distance: 0.24
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .normal, focusMode: .macro, ev: .l, flash: .off))
        XCTAssertTrue(recommendation.warnings.contains("低于 0.3 米，Mini 99 可能无法合焦"))
    }

    @MainActor
    func testBrightHighContrastSceneProtectsHighlights() {
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(
                faceLuma: 0.72,
                sceneLuma: 0.78,
                highlightRatio: 0.26,
                faceAreaRatio: 0.07,
                distance: 1.4
            )
        )

        XCTAssertEqual(recommendation.control, ExposureControl(shootingMode: .normal, focusMode: .standard, ev: .dMinus, flash: .off))
        XCTAssertTrue(recommendation.warnings.contains("背景高光有过曝风险"))
    }

    @MainActor
    func testFramedPhotoCanRenderOffMainThread() async {
        let source = solidImage(color: .red)
        let rendered = await Task.detached(priority: .userInitiated) {
            PhotoExportRenderer.framedPhoto(photo: source)
        }.value

        XCTAssertEqual(rendered.size, CGSize(width: 1176, height: 1816))
    }

    @MainActor
    func testRecommendationImageCanRenderOffMainThread() async {
        let source = solidImage(color: .red)
        let recommendation = ExposureAdvisor.decide(
            ExposureInput(faceLuma: 0.54, sceneLuma: 0.52, highlightRatio: 0.04, faceAreaRatio: 0.07, distance: 1.5)
        )
        let rendered = await Task.detached(priority: .userInitiated) {
            PhotoExportRenderer.recommendationImage(photo: source, recommendation: recommendation)
        }.value

        XCTAssertEqual(rendered.size, CGSize(width: 1080, height: 1920))
    }

    @MainActor
    func testExportedPhotoDataIsJpeg() {
        let image = PhotoExportRenderer.framedPhoto(photo: solidImage(color: .red))
        let data = PhotoLibrarySaver.encodedPhotoData(for: image)

        XCTAssertNotNil(data)
        // JPEG 文件以 FF D8 FF 开头
        XCTAssertEqual(Array((data ?? Data()).prefix(3)), [0xFF, 0xD8, 0xFF])
    }

    private func solidImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }

    private func sampledColor(in image: UIImage, at point: CGPoint) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let sample = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in
            image.draw(at: CGPoint(x: -point.x, y: -point.y))
        }

        guard let cgImage = sample.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else {
            XCTFail("Unable to sample image color")
            return (0, 0, 0)
        }

        return (
            red: CGFloat(bytes[0]) / 255,
            green: CGFloat(bytes[1]) / 255,
            blue: CGFloat(bytes[2]) / 255
        )
    }
}
