import XCTest
@testable import OctoPod

/// Golden baseline and Phase 2 fallback policy for
/// `UIUtils.calculateCameraHeightConstraints(screenHeight:portraitWidth:idiom:)`.
///
/// Known-device tuples are immutable. Unknown iPhone/iPad fallbacks are the
/// intended Phase 2 behavior, not the pre-Phase-2 `(281, 0, 211, 0)` default.
final class CameraHeightConstraintsTests: XCTestCase {

    private typealias Constraints = (
        cameraHeight4_3ConstraintPortrait: CGFloat,
        cameraHeight4_3ConstraintLandscape: CGFloat,
        camera16_9HeightConstraintPortrait: CGFloat,
        cameral16_9HeightConstraintLandscape: CGFloat
    )

    private var isMacCameraPolicy: Bool {
        ProcessInfo.processInfo.isMacCatalystApp
    }

    // MARK: - iPhone (exact screenHeight matches)

    func testIPhoneSEAndOlder() {
        assertKnownPhone(568, (183, 0, 183, 0))
    }

    func testIPhone6_7_8_SE3() {
        assertKnownPhone(667, (281, 0, 211, 0))
    }

    func testIPhone7_8Plus() {
        assertKnownPhone(736, (311, 0, 233, 0))
    }

    func testIPhoneX_Xs() {
        assertKnownPhone(812, (281, 0, 211, 0))
    }

    func testIPhone12And13MiniUseIPhoneXUIKitGeometry() {
        // UIScreen.bounds is 375×812 (same as iPhone X). Apple HIG 360×780 is
        // native 1080×2340 / 3, not the UIKit size callers pass.
        assertKnownPhone(812, (281, 0, 211, 0), portraitWidth: 375)
    }

    func testIPhone12_12Pro_14() {
        assertKnownPhone(844, (292, 0, 219, 0))
    }

    func testIPhone14Pro_16() {
        assertKnownPhone(852, (295, 0, 222, 0))
    }

    func testIPhone16Pro() {
        assertKnownPhone(874, (302, 0, 226, 0))
    }

    func testIPhoneXr_XsMax() {
        assertKnownPhone(896, (311, 0, 233, 0))
    }

    func testIPhone12ProMax_14Plus() {
        assertKnownPhone(926, (321, 0, 241, 0))
    }

    func testIPhone14ProMax_16Plus() {
        assertKnownPhone(932, (322, 0, 242, 0))
    }

    func testIPhone16ProMax() {
        assertKnownPhone(956, (330, 0, 247, 0))
    }

    func testEveryRecognizedIPhoneScreenHeight() {
        let iPhones: [(CGFloat, Constraints)] = [
            (568, (183, 0, 183, 0)),
            (667, (281, 0, 211, 0)),
            (736, (311, 0, 233, 0)),
            (812, (281, 0, 211, 0)),
            (844, (292, 0, 219, 0)),
            (852, (295, 0, 222, 0)),
            (874, (302, 0, 226, 0)),
            (896, (311, 0, 233, 0)),
            (926, (321, 0, 241, 0)),
            (932, (322, 0, 242, 0)),
            (956, (330, 0, 247, 0)),
        ]
        for (height, expected) in iPhones {
            assertKnownPhone(height, expected)
        }
    }

    func testKnownIPhoneTableWinsOverAspectFormula() {
        // 390 × 3/4 = 292.5 → Darwin round 293, but the shipped 12/14 value is 292.
        assertKnownPhone(844, (292, 0, 219, 0), portraitWidth: 390)
        // 430 × 3/4 = 322.5 → 323, shipped 14 Pro Max value is 322.
        assertKnownPhone(932, (322, 0, 242, 0), portraitWidth: 430)
        // 393 × 9/16 = 221.0625 → 221, shipped 14 Pro 16:9 value is 222.
        assertKnownPhone(852, (295, 0, 222, 0), portraitWidth: 393)
        // 440 × 9/16 = 247.5 → 248, shipped 16 Pro Max 16:9 value is 247.
        assertKnownPhone(956, (330, 0, 247, 0), portraitWidth: 440)
    }

    // MARK: - iPad (exact screenHeight matches)

    func testIPad9_7() {
        assertKnownPad(1024, (575, 348, 432, 348))
    }

    func testIPad7thGeneration10_2() {
        assertKnownPad(1080, (607, 414, 457, 414))
    }

    func testIPad10_5() {
        assertKnownPad(1112, (619, 414, 469, 414))
    }

    func testIPadMini6() {
        assertKnownPad(1133, (558, 348, 419, 348))
    }

    func testIPadAir4_Air11_iPad10th() {
        assertKnownPad(1180, (615, 414, 461, 414))
    }

    func testIPadPro11() {
        assertKnownPad(1194, (626, 414, 469, 414))
    }

    func testIPadPro11M4() {
        assertKnownPad(1210, (626, 414, 468, 414))
    }

    func testEveryRecognizedIPadExactScreenHeight() {
        let iPads: [(CGFloat, Constraints)] = [
            (1024, (575, 348, 432, 348)),
            (1080, (607, 414, 457, 414)),
            (1112, (619, 414, 469, 414)),
            (1133, (558, 348, 419, 348)),
            (1180, (615, 414, 461, 414)),
            (1194, (626, 414, 469, 414)),
            (1210, (626, 414, 468, 414)),
        ]
        for (height, expected) in iPads {
            assertKnownPad(height, expected)
        }
    }

    // MARK: - iPad range bands

    func testIPad12_9BandLowerBound1366() {
        assertKnownPad(1366, (768, 604, 576, 604))
    }

    func testIPad12_9BandInterior() {
        assertKnownPad(1370, (768, 604, 576, 604))
        assertKnownPad(1375, (768, 604, 576, 604))
    }

    func testIPad12_9BandUpperBoundIsExclusiveAt1376() {
        assertKnownPad(1375.9, (768, 604, 576, 604))
    }

    func testIPad13M4BandLowerBound1376() {
        assertKnownPad(1376, (774, 604, 580, 604))
    }

    func testIPad13M4BandUnboundedAbove() {
        assertKnownPad(1377, (774, 604, 580, 604))
        assertKnownPad(2000, (774, 604, 580, 604))
        assertKnownPad(3000, (774, 604, 580, 604))
    }

    func testIPad12_9RangeDoesNotStartAt1365() {
        // 1365 is not a known iPad height; pad fallback uses width, not the iPhone default.
        assertConstraints(screenHeight: 1365, portraitWidth: 834, idiom: .pad, expected: (626, 414, 469, 414))
        assertKnownPad(1366, (768, 604, 576, 604))
    }

    func testIPad13RangeStartsAt1376() {
        assertKnownPad(1375, (768, 604, 576, 604))
        assertKnownPad(1376, (774, 604, 580, 604))
    }

    // MARK: - SE range

    func testSERangeIncludesOlderAndZeroHeights() {
        let se: Constraints = (183, 0, 183, 0)
        assertKnownPhone(0, se)
        assertKnownPhone(480, se)
        assertKnownPhone(567, se)
        assertKnownPhone(568, se)
    }

    // MARK: - Unknown iPhone fallback

    func testUnknownIPhoneAirSizedGeometryUsesWidthFormula() {
        // 420 × 3/4 = 315, 420 × 9/16 = 236.25 → 236. Landscape stays 0.
        assertConstraints(screenHeight: 912, portraitWidth: 420, idiom: .phone, expected: (315, 0, 236, 0))
    }

    func testUnknownIPhoneHypotheticalFutureWidth() {
        // 408 × 3/4 = 306, 408 × 9/16 = 229.5 → 230.
        assertConstraints(screenHeight: 890, portraitWidth: 408, idiom: .phone, expected: (306, 0, 230, 0))
        // 446 × 3/4 = 334.5 → 335, 446 × 9/16 = 250.875 → 251.
        assertConstraints(screenHeight: 980, portraitWidth: 446, idiom: .phone, expected: (335, 0, 251, 0))
    }

    func testUnknownIPhoneGapsUseWidthFormulaNotOldDefault() {
        let width: CGFloat = 390
        let expected: Constraints = (293, 0, 219, 0)
        for height: CGFloat in [569, 666, 668, 735, 737, 811, 813, 843, 845, 851, 853, 873, 875, 895, 897, 925, 927, 931, 933, 955, 957, 1000] {
            assertConstraints(screenHeight: height, portraitWidth: width, idiom: .phone, expected: expected)
        }
    }

    func testDisplayZoomLogicalWidthUsesFillWidthFormula() {
        // Display Zoom on notched iPhones reports 320 × 693 via UIScreen.
        // Old fallback 281/211 overstated height; 320 × 3/4 = 240, × 9/16 = 180.
        assertConstraints(screenHeight: 693, portraitWidth: 320, idiom: .phone, expected: (240, 0, 180, 0))
    }

    func testUnknownIPhoneLandscapeRemainsZero() {
        let actual = UIUtils.calculateCameraHeightConstraints(screenHeight: 912, portraitWidth: 420, idiom: .phone)
        guard !isMacCameraPolicy else { return }
        XCTAssertEqual(actual.cameraHeight4_3ConstraintLandscape, 0)
        XCTAssertEqual(actual.cameral16_9HeightConstraintLandscape, 0)
    }

    // MARK: - Unknown iPad fallback

    func testUnknownIPadDoesNotUseIPhoneDefault() {
        let actual = UIUtils.calculateCameraHeightConstraints(screenHeight: 1250, portraitWidth: 834, idiom: .pad)
        guard !isMacCameraPolicy else { return }
        XCTAssertNotEqual(actual.cameraHeight4_3ConstraintPortrait, 281)
        XCTAssertNotEqual(actual.cameraHeight4_3ConstraintLandscape, 0)
        XCTAssertEqual(actual.cameraHeight4_3ConstraintPortrait, 626)
        XCTAssertEqual(actual.camera16_9HeightConstraintPortrait, 469)
        XCTAssertEqual(actual.cameraHeight4_3ConstraintLandscape, 414)
        XCTAssertEqual(actual.cameral16_9HeightConstraintLandscape, 414)
    }

    func testUnknownIPadGapsUsePadPolicy() {
        // Width 834 → 11" landscape band 414; portrait round(834*3/4)=626, round(834*9/16)=469.
        let expected: Constraints = (626, 414, 469, 414)
        for height: CGFloat in [1025, 1079, 1081, 1111, 1113, 1132, 1134, 1179, 1181, 1193, 1195, 1209, 1211] {
            assertConstraints(screenHeight: height, portraitWidth: 834, idiom: .pad, expected: expected)
        }
    }

    func testUnknownIPadLandscapeBandsFromPortraitWidth() {
        assertConstraints(screenHeight: 1200, portraitWidth: 744, idiom: .pad, expected: (558, 348, 419, 348))
        assertConstraints(screenHeight: 1200, portraitWidth: 768, idiom: .pad, expected: (576, 348, 432, 348))
        assertConstraints(screenHeight: 1200, portraitWidth: 810, idiom: .pad, expected: (608, 414, 456, 414))
        assertConstraints(screenHeight: 1200, portraitWidth: 1024, idiom: .pad, expected: (768, 604, 576, 604))
        assertConstraints(screenHeight: 1200, portraitWidth: 1032, idiom: .pad, expected: (774, 604, 581, 604))
    }

    func testUnknownIPadLandscapeBandBoundaries() {
        // Discontinuities sit between shipping iPad widths (768 then 810; 834 then 1024).
        assertConstraints(screenHeight: 1200, portraitWidth: 768, idiom: .pad, expected: (576, 348, 432, 348))
        assertConstraints(screenHeight: 1200, portraitWidth: 769, idiom: .pad, expected: (577, 414, 433, 414))
        assertConstraints(screenHeight: 1200, portraitWidth: 1023, idiom: .pad, expected: (767, 414, 575, 414))
        assertConstraints(screenHeight: 1200, portraitWidth: 1024, idiom: .pad, expected: (768, 604, 576, 604))
    }

    // MARK: - Device-family separation

    func testTallUnknownIPhoneDoesNotEnterIPadBranch() {
        let actual = UIUtils.calculateCameraHeightConstraints(screenHeight: 1366, portraitWidth: 420, idiom: .phone)
        guard !isMacCameraPolicy else { return }
        XCTAssertEqual(actual.cameraHeight4_3ConstraintPortrait, 315)
        XCTAssertEqual(actual.camera16_9HeightConstraintPortrait, 236)
        XCTAssertEqual(actual.cameraHeight4_3ConstraintLandscape, 0)
        XCTAssertNotEqual(actual.cameraHeight4_3ConstraintPortrait, 768)
    }

    func testUnknownIPadDoesNotReceiveIPhoneFallback() {
        let actual = UIUtils.calculateCameraHeightConstraints(screenHeight: 667, portraitWidth: 768, idiom: .pad)
        guard !isMacCameraPolicy else { return }
        XCTAssertNotEqual(actual.cameraHeight4_3ConstraintPortrait, 281)
        XCTAssertNotEqual(actual.camera16_9HeightConstraintPortrait, 211)
        XCTAssertNotEqual(actual.cameraHeight4_3ConstraintLandscape, 0)
        XCTAssertEqual(actual.cameraHeight4_3ConstraintPortrait, 576)
        XCTAssertEqual(actual.camera16_9HeightConstraintPortrait, 432)
        XCTAssertEqual(actual.cameraHeight4_3ConstraintLandscape, 348)
    }

    func testPhoneSERangeDoesNotApplyToIPad() {
        let actual = UIUtils.calculateCameraHeightConstraints(screenHeight: 568, portraitWidth: 768, idiom: .pad)
        guard !isMacCameraPolicy else { return }
        XCTAssertNotEqual(actual.cameraHeight4_3ConstraintPortrait, 183)
        XCTAssertEqual(actual.cameraHeight4_3ConstraintLandscape, 348)
    }

    // MARK: - Mac Catalyst

    func testMacCatalystShortCircuitsEveryScreenHeight() throws {
        try XCTSkipUnless(isMacCameraPolicy, "Mac Catalyst camera policy is not active on this host")
        let mac: Constraints = (624, 624, 624, 624)
        for height: CGFloat in [0, 568, 667, 844, 956, 1024, 1133, 1366, 1376, 2000] {
            assertConstraints(screenHeight: height, portraitWidth: 390, idiom: .phone, expected: mac)
        }
    }

    func testIOSHostDoesNotApplyMacCatalystFixedHeight() throws {
        try XCTSkipIf(isMacCameraPolicy, "Mac Catalyst overrides all screen heights")
        let actual = UIUtils.calculateCameraHeightConstraints(screenHeight: 667, portraitWidth: 375, idiom: .phone)
        XCTAssertNotEqual(actual.cameraHeight4_3ConstraintPortrait, 624)
        XCTAssertEqual(actual.cameraHeight4_3ConstraintPortrait, 281)
    }

    // MARK: - Caller portrait-edge normalization

    func testPortraitBoundsUseHeightAsLongEdge() {
        let dims = UIUtils.cameraPortraitScreenDimensions(from: CGRect(x: 0, y: 0, width: 390, height: 844))
        XCTAssertEqual(dims.height, 844)
        XCTAssertEqual(dims.width, 390)
    }

    func testLandscapeBoundsNormalizeToTheSamePortraitEdges() {
        let portrait = UIUtils.cameraPortraitScreenDimensions(from: CGRect(x: 0, y: 0, width: 390, height: 844))
        let landscape = UIUtils.cameraPortraitScreenDimensions(from: CGRect(x: 0, y: 0, width: 844, height: 390))
        XCTAssertEqual(portrait.height, landscape.height)
        XCTAssertEqual(portrait.width, landscape.width)
        XCTAssertEqual(landscape.height, 844)
        XCTAssertEqual(landscape.width, 390)
    }

    func testMiniNativePanelDoesNotChangeUIKitPortraitEdges() {
        // Physical 1080×2340 would be 360×780 at @3x. UIKit still uses 375×812.
        let dims = UIUtils.cameraPortraitScreenDimensions(from: CGRect(x: 0, y: 0, width: 375, height: 812))
        XCTAssertEqual(dims.height, 812)
        XCTAssertEqual(dims.width, 375)
        assertKnownPhone(dims.height, (281, 0, 211, 0), portraitWidth: dims.width)
    }

    func testHostMiniReportsUIKit375x812NotHIG360x780() {
        let screen = UIScreen.main
        let nativePortraitWidth = min(screen.nativeBounds.width, screen.nativeBounds.height)
        let nativePortraitHeight = max(screen.nativeBounds.width, screen.nativeBounds.height)
        guard nativePortraitWidth == 1080, nativePortraitHeight == 2340 else {
            return
        }
        let dims = UIUtils.cameraPortraitScreenDimensions(from: screen.bounds)
        XCTAssertEqual(dims.width, 375)
        XCTAssertEqual(dims.height, 812)
    }

    // MARK: - Helpers

    private func assertKnownPhone(_ screenHeight: CGFloat, _ iOSExpected: Constraints, portraitWidth: CGFloat? = nil, file: StaticString = #filePath, line: UInt = #line) {
        assertConstraints(screenHeight: screenHeight, portraitWidth: portraitWidth, idiom: .phone, expected: iOSExpected, file: file, line: line)
    }

    private func assertKnownPad(_ screenHeight: CGFloat, _ iOSExpected: Constraints, portraitWidth: CGFloat? = nil, file: StaticString = #filePath, line: UInt = #line) {
        assertConstraints(screenHeight: screenHeight, portraitWidth: portraitWidth, idiom: .pad, expected: iOSExpected, file: file, line: line)
    }

    private func assertConstraints(screenHeight: CGFloat, portraitWidth: CGFloat?, idiom: UIUserInterfaceIdiom, expected: Constraints, file: StaticString = #filePath, line: UInt = #line) {
        let iOSExpected = expected
        let expectedTuple: Constraints = isMacCameraPolicy ? (624, 624, 624, 624) : iOSExpected
        let actual = UIUtils.calculateCameraHeightConstraints(screenHeight: screenHeight, portraitWidth: portraitWidth, idiom: idiom)
        XCTAssertEqual(
            actual.cameraHeight4_3ConstraintPortrait,
            expectedTuple.cameraHeight4_3ConstraintPortrait,
            "4:3 portrait for screenHeight \(screenHeight) width \(String(describing: portraitWidth)) idiom \(idiom.rawValue)",
            file: file,
            line: line
        )
        XCTAssertEqual(
            actual.cameraHeight4_3ConstraintLandscape,
            expectedTuple.cameraHeight4_3ConstraintLandscape,
            "4:3 landscape for screenHeight \(screenHeight) width \(String(describing: portraitWidth)) idiom \(idiom.rawValue)",
            file: file,
            line: line
        )
        XCTAssertEqual(
            actual.camera16_9HeightConstraintPortrait,
            expectedTuple.camera16_9HeightConstraintPortrait,
            "16:9 portrait for screenHeight \(screenHeight) width \(String(describing: portraitWidth)) idiom \(idiom.rawValue)",
            file: file,
            line: line
        )
        XCTAssertEqual(
            actual.cameral16_9HeightConstraintLandscape,
            expectedTuple.cameral16_9HeightConstraintLandscape,
            "16:9 landscape for screenHeight \(screenHeight) width \(String(describing: portraitWidth)) idiom \(idiom.rawValue)",
            file: file,
            line: line
        )
    }
}
