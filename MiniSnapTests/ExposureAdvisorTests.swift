import CoreGraphics
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
        XCTAssertEqual(recommendation.control.focusMode.rangeText, "0.3-0.6m")
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
}
