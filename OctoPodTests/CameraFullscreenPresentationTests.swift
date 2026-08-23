import XCTest
@testable import OctoPod

final class CameraFullscreenPresentationTests: XCTestCase {

    func testPortraitDetectionUsesDisplayedSize() {
        XCTAssertTrue(CameraFullscreenPresentation.isPortraitDisplay(CGSize(width: 736, height: 1312)))
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(CGSize(width: 1312, height: 736)))
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(CGSize(width: 800, height: 800)))
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(.zero))
    }

    func testDisplayedSizeSwapsForLeftAndRightOrientations() {
        let landscapePixels = CGSize(width: 1312, height: 736)
        XCTAssertEqual(CameraFullscreenPresentation.displayedSize(pixelSize: landscapePixels, orientation: .up), landscapePixels)
        XCTAssertEqual(CameraFullscreenPresentation.displayedSize(pixelSize: landscapePixels, orientation: .left), CGSize(width: 736, height: 1312))
        XCTAssertEqual(CameraFullscreenPresentation.displayedSize(pixelSize: landscapePixels, orientation: .right), CGSize(width: 736, height: 1312))
        XCTAssertEqual(CameraFullscreenPresentation.displayedSize(pixelSize: landscapePixels, orientation: .down), landscapePixels)

        let portraitPixels = CGSize(width: 736, height: 1312)
        XCTAssertTrue(CameraFullscreenPresentation.isPortraitDisplay(CameraFullscreenPresentation.displayedSize(pixelSize: portraitPixels, orientation: .up)))
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(CameraFullscreenPresentation.displayedSize(pixelSize: landscapePixels, orientation: .up)))
        XCTAssertTrue(CameraFullscreenPresentation.isPortraitDisplay(CameraFullscreenPresentation.displayedSize(pixelSize: landscapePixels, orientation: .left)))
    }

    func testCounterclockwiseRotationOrientationTable() {
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.up), .left)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.left), .down)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.down), .right)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.right), .up)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.upMirrored), .leftMirrored)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.leftMirrored), .downMirrored)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.downMirrored), .rightMirrored)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.rightMirrored), .upMirrored)
    }

    func testRepeatedRotationIsNotIdempotentWithoutRestore() {
        let twice = CameraFullscreenPresentation.orientationByRotating90Counterclockwise(
            CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.up)
        )
        XCTAssertEqual(twice, .down)
        XCTAssertNotEqual(twice, CameraFullscreenPresentation.orientationByRotating90Counterclockwise(.up))
    }

    func testFourCounterclockwiseRotationsRestoreOriginalOrientation() {
        var orientation = UIImage.Orientation.up
        for _ in 0..<4 {
            orientation = CameraFullscreenPresentation.orientationByRotating90Counterclockwise(orientation)
        }
        XCTAssertEqual(orientation, .up)
    }

    func testFullscreenRotationTurnsPortraitDisplayIntoLandscapeWithoutChangingPixels() {
        let image = makeImage(width: 736, height: 1312, orientation: .up)
        XCTAssertTrue(CameraFullscreenPresentation.isPortraitDisplay(image.size))

        let fullscreenOrientation = CameraFullscreenPresentation.orientationByRotating90Counterclockwise(image.imageOrientation)
        let fullscreenImage = CameraFullscreenPresentation.imageByReplacingOrientation(image, orientation: fullscreenOrientation)

        XCTAssertEqual(fullscreenImage.size, CGSize(width: 1312, height: 736))
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(fullscreenImage.size))
        XCTAssertEqual(fullscreenImage.cgImage?.width, image.cgImage?.width)
        XCTAssertEqual(fullscreenImage.cgImage?.height, image.cgImage?.height)
        XCTAssertEqual(fullscreenImage.size.width / fullscreenImage.size.height, image.size.height / image.size.width, accuracy: 0.0001)
        XCTAssertEqual(fullscreenImage.imageOrientation, .left)
    }

    func testOctoPrintRotate90PortraitDisplayBecomesLandscapeAfterFullscreenRotation() {
        let image = makeImage(width: 1312, height: 736, orientation: .left)
        XCTAssertEqual(image.size, CGSize(width: 736, height: 1312))
        XCTAssertTrue(CameraFullscreenPresentation.isPortraitDisplay(image.size))

        let fullscreenImage = CameraFullscreenPresentation.imageByReplacingOrientation(
            image,
            orientation: CameraFullscreenPresentation.orientationByRotating90Counterclockwise(image.imageOrientation)
        )
        XCTAssertEqual(fullscreenImage.size, CGSize(width: 1312, height: 736))
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(fullscreenImage.size))
        XCTAssertEqual(fullscreenImage.imageOrientation, .down)
    }

    func testReplacingOrientationRestoresEmbeddedPresentation() {
        let original = makeImage(width: 736, height: 1312, orientation: .up)
        let fullscreenImage = CameraFullscreenPresentation.imageByReplacingOrientation(
            original,
            orientation: CameraFullscreenPresentation.orientationByRotating90Counterclockwise(original.imageOrientation)
        )
        let restored = CameraFullscreenPresentation.imageByReplacingOrientation(fullscreenImage, orientation: .up)

        XCTAssertEqual(restored.size, original.size)
        XCTAssertEqual(restored.imageOrientation, original.imageOrientation)
        XCTAssertEqual(restored.cgImage?.width, original.cgImage?.width)
        XCTAssertEqual(restored.cgImage?.height, original.cgImage?.height)
    }

    func testLandscapeImagesAreNotPortrait() {
        let image = makeImage(width: 1280, height: 720, orientation: .up)
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(image.size))
        XCTAssertEqual(
            CameraFullscreenPresentation.displayedSize(pixelSize: image.size, orientation: .up),
            image.size
        )
    }

    func testIPhonePortraitFullscreenAppliesCounterclockwiseCorrection() {
        XCTAssertTrue(
            CameraFullscreenPresentation.shouldApplyFullscreenPortraitImageRotation(
                userInterfaceIdiom: .phone,
                isFullscreen: true,
                isPortraitDisplay: true
            )
        )
        XCTAssertEqual(
            CameraFullscreenPresentation.imageOrientationForPresentation(
                configuredOrientation: .up,
                displayedSize: CGSize(width: 736, height: 1312),
                isFullscreen: true,
                userInterfaceIdiom: .phone
            ),
            .left
        )
        XCTAssertEqual(
            CameraFullscreenPresentation.imageOrientationForPresentation(
                configuredOrientation: .left,
                displayedSize: CGSize(width: 736, height: 1312),
                isFullscreen: true,
                userInterfaceIdiom: .phone
            ),
            .down
        )
    }

    func testIPadPortraitFullscreenPreservesConfiguredOrientation() {
        XCTAssertFalse(
            CameraFullscreenPresentation.shouldApplyFullscreenPortraitImageRotation(
                userInterfaceIdiom: .pad,
                isFullscreen: true,
                isPortraitDisplay: true
            )
        )
        XCTAssertEqual(
            CameraFullscreenPresentation.imageOrientationForPresentation(
                configuredOrientation: .up,
                displayedSize: CGSize(width: 736, height: 1312),
                isFullscreen: true,
                userInterfaceIdiom: .pad
            ),
            .up
        )
        XCTAssertEqual(
            CameraFullscreenPresentation.imageOrientationForPresentation(
                configuredOrientation: .left,
                displayedSize: CGSize(width: 736, height: 1312),
                isFullscreen: true,
                userInterfaceIdiom: .pad
            ),
            .left
        )
    }

    func testLandscapeSourceUnchangedOnIPhoneAndIPad() {
        let landscape = CGSize(width: 1280, height: 720)
        for idiom: UIUserInterfaceIdiom in [.phone, .pad] {
            XCTAssertFalse(
                CameraFullscreenPresentation.shouldApplyFullscreenPortraitImageRotation(
                    userInterfaceIdiom: idiom,
                    isFullscreen: true,
                    isPortraitDisplay: false
                )
            )
            XCTAssertEqual(
                CameraFullscreenPresentation.imageOrientationForPresentation(
                    configuredOrientation: .up,
                    displayedSize: landscape,
                    isFullscreen: true,
                    userInterfaceIdiom: idiom
                ),
                .up
            )
        }
    }

    func testExitingFullscreenRestoresConfiguredOrientation() {
        let portrait = CGSize(width: 736, height: 1312)
        let configured = UIImage.Orientation.up
        for idiom: UIUserInterfaceIdiom in [.phone, .pad] {
            let restored = CameraFullscreenPresentation.imageOrientationForPresentation(
                configuredOrientation: configured,
                displayedSize: portrait,
                isFullscreen: false,
                userInterfaceIdiom: idiom
            )
            XCTAssertEqual(restored, configured)
        }
        XCTAssertEqual(
            CameraFullscreenPresentation.imageOrientationForPresentation(
                configuredOrientation: configured,
                displayedSize: portrait,
                isFullscreen: true,
                userInterfaceIdiom: .phone
            ),
            .left
        )
        XCTAssertEqual(
            CameraFullscreenPresentation.imageOrientationForPresentation(
                configuredOrientation: configured,
                displayedSize: portrait,
                isFullscreen: true,
                userInterfaceIdiom: .pad
            ),
            configured
        )
    }

    func testRepeatedFullscreenEnterExitDoesNotAccumulateOrientation() {
        let portrait = CGSize(width: 736, height: 1312)
        let configured = UIImage.Orientation.up
        for _ in 0..<4 {
            XCTAssertEqual(
                CameraFullscreenPresentation.imageOrientationForPresentation(
                    configuredOrientation: configured,
                    displayedSize: portrait,
                    isFullscreen: true,
                    userInterfaceIdiom: .phone
                ),
                .left
            )
            XCTAssertEqual(
                CameraFullscreenPresentation.imageOrientationForPresentation(
                    configuredOrientation: configured,
                    displayedSize: portrait,
                    isFullscreen: false,
                    userInterfaceIdiom: .phone
                ),
                configured
            )
            XCTAssertEqual(
                CameraFullscreenPresentation.imageOrientationForPresentation(
                    configuredOrientation: configured,
                    displayedSize: portrait,
                    isFullscreen: true,
                    userInterfaceIdiom: .pad
                ),
                configured
            )
        }
    }

    private func makeImage(width: Int, height: Int, orientation: UIImage.Orientation) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let raw = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return UIImage(cgImage: raw.cgImage!, scale: raw.scale, orientation: orientation)
    }
}

final class CameraFullscreenStatusOverlayTests: XCTestCase {

    func testInvalidPhysicalOrientationsKeepLastValid() {
        XCTAssertEqual(CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(.faceUp, lastValid: .portrait), .portrait)
        XCTAssertEqual(CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(.faceDown, lastValid: .landscapeRight), .landscapeRight)
        XCTAssertEqual(CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(.unknown, lastValid: .landscapeLeft), .landscapeLeft)
    }

    func testValidPhysicalOrientationsReplaceLastValid() {
        XCTAssertEqual(CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(.portrait, lastValid: .landscapeLeft), .portrait)
        XCTAssertEqual(CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(.portraitUpsideDown, lastValid: .portrait), .portraitUpsideDown)
        XCTAssertEqual(CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(.landscapeLeft, lastValid: .portrait), .landscapeLeft)
        XCTAssertEqual(CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(.landscapeRight, lastValid: .portrait), .landscapeRight)
    }

    func testPlacementMapsPhysicalOrientationToForcedLandscapeCoordinates() {
        let portrait = CameraFullscreenStatusOverlay.placement(physicalOrientation: .portrait)
        XCTAssertEqual(portrait.corner, .topLeft)
        XCTAssertEqual(portrait.rotationRadians, -.pi / 2, accuracy: 0.0001)

        let landscapeLeft = CameraFullscreenStatusOverlay.placement(physicalOrientation: .landscapeLeft)
        XCTAssertEqual(landscapeLeft.corner, .topRight)
        XCTAssertEqual(landscapeLeft.rotationRadians, 0, accuracy: 0.0001)

        let landscapeRight = CameraFullscreenStatusOverlay.placement(physicalOrientation: .landscapeRight)
        XCTAssertEqual(landscapeRight.corner, .bottomLeft)
        XCTAssertEqual(landscapeRight.rotationRadians, .pi, accuracy: 0.0001)

        let upsideDown = CameraFullscreenStatusOverlay.placement(physicalOrientation: .portraitUpsideDown)
        XCTAssertEqual(upsideDown.corner, .bottomRight)
        XCTAssertEqual(upsideDown.rotationRadians, .pi / 2, accuracy: 0.0001)
    }

    func testPortraitCompensationIsInverseOfDeviceRotationFromIdentity() {
        XCTAssertEqual(CameraFullscreenStatusOverlay.clockwiseRadiansFromPortrait(.portrait), 0, accuracy: 0.0001)
        XCTAssertEqual(CameraFullscreenStatusOverlay.clockwiseRadiansFromPortrait(.landscapeRight), .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(CameraFullscreenStatusOverlay.clockwiseRadiansFromPortrait(.portraitUpsideDown), .pi, accuracy: 0.0001)
        XCTAssertEqual(CameraFullscreenStatusOverlay.clockwiseRadiansFromPortrait(.landscapeLeft), 3 * .pi / 2, accuracy: 0.0001)

        // Matching hold for forced landscapeRight: no extra overlay rotation.
        XCTAssertEqual(
            CameraFullscreenStatusOverlay.overlayRotationRadians(physicalOrientation: .landscapeLeft),
            0,
            accuracy: 0.0001
        )
        // Physical portrait is 90° clockwise from that identity, so compensate CCW.
        XCTAssertEqual(
            CameraFullscreenStatusOverlay.overlayRotationRadians(physicalOrientation: .portrait),
            -.pi / 2,
            accuracy: 0.0001
        )
    }

    func testOldPortraitMappingIsNotUsed() {
        let portrait = CameraFullscreenStatusOverlay.placement(physicalOrientation: .portrait)
        XCTAssertNotEqual(portrait.corner, .bottomRight)
        XCTAssertNotEqual(portrait.rotationRadians, .pi / 2, accuracy: 0.0001)
    }

    func testLegacyForceSuppressionIsScopedToIOS15SetValuePath() {
        XCTAssertFalse(
            CameraFullscreenStatusOverlay.shouldSuppressLegacyForcedLandscapeArtifact(
                usedLegacyDeviceOrientationForce: false,
                lastValidPhysicalOrientation: .portrait
            )
        )
        XCTAssertTrue(
            CameraFullscreenStatusOverlay.shouldSuppressLegacyForcedLandscapeArtifact(
                usedLegacyDeviceOrientationForce: true,
                lastValidPhysicalOrientation: .portrait
            )
        )
        XCTAssertTrue(
            CameraFullscreenStatusOverlay.shouldSuppressLegacyForcedLandscapeArtifact(
                usedLegacyDeviceOrientationForce: true,
                lastValidPhysicalOrientation: .landscapeRight
            )
        )
        XCTAssertFalse(
            CameraFullscreenStatusOverlay.shouldSuppressLegacyForcedLandscapeArtifact(
                usedLegacyDeviceOrientationForce: true,
                lastValidPhysicalOrientation: .landscapeLeft
            )
        )
    }

    func testInvalidOrientationPlacementUsesIdentityLandscapeCorner() {
        let placement = CameraFullscreenStatusOverlay.placement(physicalOrientation: .faceUp)
        XCTAssertEqual(placement.corner, .topRight)
        XCTAssertEqual(placement.rotationRadians, 0, accuracy: 0.0001)
    }

    func testSamePhysicalPortraitProducesSameCenterAfterVisitingLandscape() {
        let host = CGRect(x: 0, y: 0, width: 844, height: 390)
        let insets = UIEdgeInsets(top: 0, left: 16, bottom: 21, right: 47)
        let size = CGSize(width: 90, height: 52)

        func center(for orientation: UIDeviceOrientation) -> CGPoint {
            let placement = CameraFullscreenStatusOverlay.placement(physicalOrientation: orientation)
            let target = CameraFullscreenStatusOverlay.targetPoint(
                in: host,
                safeAreaInsets: insets,
                corner: placement.corner,
                topInset: 6,
                sideInset: 10
            )
            return CameraFullscreenStatusOverlay.overlayCenter(
                size: size,
                targetTopRight: target,
                rotationRadians: placement.rotationRadians
            )
        }

        let initialPortrait = center(for: .portrait)
        _ = center(for: .landscapeLeft)
        let portraitAfterLandscapeLeft = center(for: .portrait)
        XCTAssertEqual(initialPortrait.x, portraitAfterLandscapeLeft.x, accuracy: 0.0001)
        XCTAssertEqual(initialPortrait.y, portraitAfterLandscapeLeft.y, accuracy: 0.0001)

        _ = center(for: .landscapeRight)
        let portraitAfterLandscapeRight = center(for: .portrait)
        XCTAssertEqual(initialPortrait.x, portraitAfterLandscapeRight.x, accuracy: 0.0001)
        XCTAssertEqual(initialPortrait.y, portraitAfterLandscapeRight.y, accuracy: 0.0001)
    }

    func testOverlayCenterPutsLocalTopRightOnTargetAfterRotation() {
        let size = CGSize(width: 80, height: 40)
        let target = CGPoint(x: 200, y: 100)
        let rotations: [CGFloat] = [0, .pi / 2, .pi, -.pi / 2]

        for rotation in rotations {
            let center = CameraFullscreenStatusOverlay.overlayCenter(size: size, targetTopRight: target, rotationRadians: rotation)
            let localTopRight = CGPoint(x: size.width / 2, y: -size.height / 2)
            let rotated = localTopRight.applying(CGAffineTransform(rotationAngle: rotation))
            XCTAssertEqual(center.x + rotated.x, target.x, accuracy: 0.0001)
            XCTAssertEqual(center.y + rotated.y, target.y, accuracy: 0.0001)
        }
    }

    func testTargetPointUsesMatchingSafeAreaEdges() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 400)
        let insets = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        XCTAssertEqual(
            CameraFullscreenStatusOverlay.targetPoint(in: bounds, safeAreaInsets: insets, corner: .topRight, topInset: 6, sideInset: 10),
            CGPoint(x: 750, y: 16)
        )
        XCTAssertEqual(
            CameraFullscreenStatusOverlay.targetPoint(in: bounds, safeAreaInsets: insets, corner: .bottomRight, topInset: 6, sideInset: 10),
            CGPoint(x: 750, y: 364)
        )
        XCTAssertEqual(
            CameraFullscreenStatusOverlay.targetPoint(in: bounds, safeAreaInsets: insets, corner: .bottomLeft, topInset: 6, sideInset: 10),
            CGPoint(x: 30, y: 364)
        )
        XCTAssertEqual(
            CameraFullscreenStatusOverlay.targetPoint(in: bounds, safeAreaInsets: insets, corner: .topLeft, topInset: 6, sideInset: 10),
            CGPoint(x: 30, y: 16)
        )
    }
}

final class CameraFullscreenSessionTests: XCTestCase {

    func testIPhoneFullscreenLocksToLandscapeRight() {
        XCTAssertEqual(
            CameraFullscreenSession.supportedInterfaceOrientations(
                userInterfaceIdiom: .phone,
                isFullscreen: true,
                canEnforceLandscapeSession: true,
                fallback: .allButUpsideDown
            ),
            .landscapeRight
        )
        XCTAssertEqual(
            CameraFullscreenSession.preferredInterfaceOrientation(
                userInterfaceIdiom: .phone,
                isFullscreen: true,
                canEnforceLandscapeSession: true,
                fallback: .portrait
            ),
            .landscapeRight
        )
    }

    func testIPhoneFullscreenLockIgnoresCanEnforceFlag() {
        XCTAssertTrue(
            CameraFullscreenSession.shouldLockInterfaceToLandscapeRight(
                userInterfaceIdiom: .phone,
                isFullscreen: true,
                canEnforceLandscapeSession: false
            )
        )
        XCTAssertEqual(
            CameraFullscreenSession.supportedInterfaceOrientations(
                userInterfaceIdiom: .phone,
                isFullscreen: true,
                canEnforceLandscapeSession: false,
                fallback: .allButUpsideDown
            ),
            .landscapeRight
        )
    }

    func testIPhoneNonFullscreenKeepsFallbackPolicy() {
        XCTAssertEqual(
            CameraFullscreenSession.supportedInterfaceOrientations(
                userInterfaceIdiom: .phone,
                isFullscreen: false,
                canEnforceLandscapeSession: true,
                fallback: .allButUpsideDown
            ),
            .allButUpsideDown
        )
        XCTAssertEqual(
            CameraFullscreenSession.preferredInterfaceOrientation(
                userInterfaceIdiom: .phone,
                isFullscreen: false,
                canEnforceLandscapeSession: true,
                fallback: .portrait
            ),
            .portrait
        )
    }

    func testIPadFullScreenSceneLocksToLandscapeRight() {
        XCTAssertEqual(
            CameraFullscreenSession.supportedInterfaceOrientations(
                userInterfaceIdiom: .pad,
                isFullscreen: true,
                canEnforceLandscapeSession: true,
                fallback: .all
            ),
            .landscapeRight
        )
        XCTAssertEqual(
            CameraFullscreenSession.preferredInterfaceOrientation(
                userInterfaceIdiom: .pad,
                isFullscreen: true,
                canEnforceLandscapeSession: true,
                fallback: .portrait
            ),
            .landscapeRight
        )
    }

    func testIPadMultitaskingSceneKeepsFallbackPolicy() {
        XCTAssertEqual(
            CameraFullscreenSession.supportedInterfaceOrientations(
                userInterfaceIdiom: .pad,
                isFullscreen: true,
                canEnforceLandscapeSession: false,
                fallback: .all
            ),
            .all
        )
        XCTAssertEqual(
            CameraFullscreenSession.preferredInterfaceOrientation(
                userInterfaceIdiom: .pad,
                isFullscreen: true,
                canEnforceLandscapeSession: false,
                fallback: .portrait
            ),
            .portrait
        )
    }

    func testIPadNonFullscreenKeepsFallbackPolicy() {
        XCTAssertEqual(
            CameraFullscreenSession.supportedInterfaceOrientations(
                userInterfaceIdiom: .pad,
                isFullscreen: false,
                canEnforceLandscapeSession: true,
                fallback: .all
            ),
            .all
        )
    }

    func testWindowOccupiesFullScreenAllowsRotatedFullDisplay() {
        XCTAssertTrue(CameraFullscreenSession.occupiesFullScreen(
            windowSize: CGSize(width: 1024, height: 768),
            screenSize: CGSize(width: 1024, height: 768)
        ))
        XCTAssertTrue(CameraFullscreenSession.occupiesFullScreen(
            windowSize: CGSize(width: 768, height: 1024),
            screenSize: CGSize(width: 1024, height: 768)
        ))
        XCTAssertFalse(CameraFullscreenSession.occupiesFullScreen(
            windowSize: CGSize(width: 320, height: 768),
            screenSize: CGSize(width: 1024, height: 768)
        ))
        XCTAssertFalse(CameraFullscreenSession.occupiesFullScreen(
            windowSize: CGSize(width: 600, height: 500),
            screenSize: CGSize(width: 1024, height: 768)
        ))
    }

    func testOneShotLandscapeForceMatchesLockPolicy() {
        XCTAssertTrue(
            CameraFullscreenSession.shouldForceLandscapeGeometry(
                userInterfaceIdiom: .phone,
                isFullscreen: true,
                canEnforceLandscapeSession: false
            )
        )
        XCTAssertTrue(
            CameraFullscreenSession.shouldForceLandscapeGeometry(
                userInterfaceIdiom: .pad,
                isFullscreen: true,
                canEnforceLandscapeSession: true
            )
        )
        XCTAssertFalse(
            CameraFullscreenSession.shouldForceLandscapeGeometry(
                userInterfaceIdiom: .pad,
                isFullscreen: true,
                canEnforceLandscapeSession: false
            )
        )
        XCTAssertFalse(
            CameraFullscreenSession.shouldForceLandscapeGeometry(
                userInterfaceIdiom: .phone,
                isFullscreen: false,
                canEnforceLandscapeSession: true
            )
        )
    }
}

final class CameraFullscreenContainerTests: XCTestCase {

    func testOnlyCurrentCameraIsFullscreenWhenContainerIsFullscreen() {
        XCTAssertEqual(
            CameraFullscreenContainer.camerasWithFullscreenPresentation(
                cameraIDs: ["A", "B", "C"],
                currentID: "A",
                containerFullscreen: true
            ),
            ["A"]
        )
        XCTAssertTrue(
            CameraFullscreenContainer.isFullscreenActive(containerFullscreen: true, isCurrentCamera: true)
        )
        XCTAssertFalse(
            CameraFullscreenContainer.isFullscreenActive(containerFullscreen: true, isCurrentCamera: false)
        )
    }

    func testReplacementKeepsFullscreenOnNewCurrentOnly() {
        let before = CameraFullscreenContainer.camerasWithFullscreenPresentation(
            cameraIDs: ["old"],
            currentID: "old",
            containerFullscreen: true
        )
        XCTAssertEqual(before, ["old"])
        let after = CameraFullscreenContainer.camerasWithFullscreenPresentation(
            cameraIDs: ["new-a", "new-b"],
            currentID: "new-a",
            containerFullscreen: true
        )
        XCTAssertEqual(after, ["new-a"])
        XCTAssertFalse(after.contains("old"))
    }

    func testRemovalResetsFullscreenToFirstRemainingCamera() {
        XCTAssertEqual(
            CameraFullscreenContainer.camerasWithFullscreenPresentation(
                cameraIDs: ["kept"],
                currentID: "removed",
                containerFullscreen: true
            ),
            []
        )
        XCTAssertEqual(
            CameraFullscreenContainer.camerasWithFullscreenPresentation(
                cameraIDs: ["kept"],
                currentID: "kept",
                containerFullscreen: true
            ),
            ["kept"]
        )
    }

    func testCameraSwitchMovesFullscreenToNewCurrent() {
        XCTAssertEqual(
            CameraFullscreenContainer.camerasWithFullscreenPresentation(
                cameraIDs: ["A", "B"],
                currentID: "B",
                containerFullscreen: true
            ),
            ["B"]
        )
    }

    func testNonCurrentCamerasAreClearedWhenContainerExitsFullscreen() {
        XCTAssertEqual(
            CameraFullscreenContainer.camerasWithFullscreenPresentation(
                cameraIDs: ["A", "B", "C"],
                currentID: "A",
                containerFullscreen: false
            ),
            []
        )
    }
}

final class CameraFullscreenPhysicalOrientationFallbackTests: XCTestCase {

    func testMotionErrorFallsBackOnceBeforeUsableSample() {
        XCTAssertTrue(
            CameraFullscreenPhysicalOrientation.shouldFallbackToDeviceOrientation(
                motionError: true,
                receivedUsableMotion: false,
                alreadyFellBack: false
            )
        )
        XCTAssertFalse(
            CameraFullscreenPhysicalOrientation.shouldFallbackToDeviceOrientation(
                motionError: true,
                receivedUsableMotion: false,
                alreadyFellBack: true
            )
        )
        XCTAssertFalse(
            CameraFullscreenPhysicalOrientation.shouldFallbackToDeviceOrientation(
                motionError: true,
                receivedUsableMotion: true,
                alreadyFellBack: false
            )
        )
        XCTAssertFalse(
            CameraFullscreenPhysicalOrientation.shouldFallbackToDeviceOrientation(
                motionError: false,
                receivedUsableMotion: false,
                alreadyFellBack: false
            )
        )
    }
}

final class CameraFullscreenIPadOverlayTests: XCTestCase {

    func testIPhoneDefaultPlacementMatchesExplicitLandscapeRightInterface() {
        let orientations: [UIDeviceOrientation] = [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown]
        for orientation in orientations {
            XCTAssertEqual(
                CameraFullscreenStatusOverlay.placement(physicalOrientation: orientation),
                CameraFullscreenStatusOverlay.placement(
                    physicalOrientation: orientation,
                    interfaceOrientation: .landscapeRight
                )
            )
        }
    }

    func testDeviceOrientationMatchingUsesLandscapeNameInversion() {
        XCTAssertEqual(CameraFullscreenStatusOverlay.deviceOrientationMatching(.landscapeRight), .landscapeLeft)
        XCTAssertEqual(CameraFullscreenStatusOverlay.deviceOrientationMatching(.landscapeLeft), .landscapeRight)
        XCTAssertEqual(CameraFullscreenStatusOverlay.deviceOrientationMatching(.portrait), .portrait)
        XCTAssertEqual(CameraFullscreenStatusOverlay.deviceOrientationMatching(.portraitUpsideDown), .portraitUpsideDown)
        XCTAssertEqual(CameraFullscreenStatusOverlay.deviceOrientationMatching(.unknown), .landscapeLeft)
    }

    func testIPadLandscapeRightInterfaceUsesSameMappingAsIPhone() {
        let portrait = CameraFullscreenStatusOverlay.placement(
            physicalOrientation: .portrait,
            interfaceOrientation: .landscapeRight
        )
        XCTAssertEqual(portrait.corner, .topLeft)
        XCTAssertEqual(portrait.rotationRadians, -.pi / 2, accuracy: 0.0001)

        let landscapeLeft = CameraFullscreenStatusOverlay.placement(
            physicalOrientation: .landscapeLeft,
            interfaceOrientation: .landscapeRight
        )
        XCTAssertEqual(landscapeLeft.corner, .topRight)
        XCTAssertEqual(landscapeLeft.rotationRadians, 0, accuracy: 0.0001)

        let landscapeRight = CameraFullscreenStatusOverlay.placement(
            physicalOrientation: .landscapeRight,
            interfaceOrientation: .landscapeRight
        )
        XCTAssertEqual(landscapeRight.corner, .bottomLeft)
        XCTAssertEqual(landscapeRight.rotationRadians, .pi, accuracy: 0.0001)

        let upsideDown = CameraFullscreenStatusOverlay.placement(
            physicalOrientation: .portraitUpsideDown,
            interfaceOrientation: .landscapeRight
        )
        XCTAssertEqual(upsideDown.corner, .bottomRight)
        XCTAssertEqual(upsideDown.rotationRadians, .pi / 2, accuracy: 0.0001)
    }

    func testIPadLandscapeLeftInterfaceUsesSwappedIdentity() {
        let matching = CameraFullscreenStatusOverlay.placement(
            physicalOrientation: .landscapeRight,
            interfaceOrientation: .landscapeLeft
        )
        XCTAssertEqual(matching.corner, .topRight)
        XCTAssertEqual(matching.rotationRadians, 0, accuracy: 0.0001)

        let opposite = CameraFullscreenStatusOverlay.placement(
            physicalOrientation: .landscapeLeft,
            interfaceOrientation: .landscapeLeft
        )
        XCTAssertEqual(opposite.corner, .bottomLeft)
        XCTAssertEqual(opposite.rotationRadians, .pi, accuracy: 0.0001)

        let portrait = CameraFullscreenStatusOverlay.placement(
            physicalOrientation: .portrait,
            interfaceOrientation: .landscapeLeft
        )
        XCTAssertEqual(portrait.corner, .bottomRight)
        XCTAssertEqual(portrait.rotationRadians, .pi / 2, accuracy: 0.0001)

        let upsideDown = CameraFullscreenStatusOverlay.placement(
            physicalOrientation: .portraitUpsideDown,
            interfaceOrientation: .landscapeLeft
        )
        XCTAssertEqual(upsideDown.corner, .topLeft)
        XCTAssertEqual(upsideDown.rotationRadians, -.pi / 2, accuracy: 0.0001)
    }

    func testIPadFourHoldSequenceIsHistoryIndependent() {
        let host = CGRect(x: 0, y: 0, width: 1366, height: 1024)
        let insets = UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0)
        let size = CGSize(width: 90, height: 52)
        let sequence: [UIDeviceOrientation] = [
            .portrait, .landscapeLeft, .portraitUpsideDown, .landscapeRight, .portrait
        ]

        func center(for orientation: UIDeviceOrientation) -> CGPoint {
            let placement = CameraFullscreenStatusOverlay.placement(
                physicalOrientation: orientation,
                interfaceOrientation: .landscapeRight
            )
            let target = CameraFullscreenStatusOverlay.targetPoint(
                in: host,
                safeAreaInsets: insets,
                corner: placement.corner,
                topInset: 6,
                sideInset: 10
            )
            return CameraFullscreenStatusOverlay.overlayCenter(
                size: size,
                targetTopRight: target,
                rotationRadians: placement.rotationRadians
            )
        }

        let firstPortrait = center(for: .portrait)
        for orientation in sequence {
            _ = center(for: orientation)
        }
        let portraitAfterLoop = center(for: .portrait)
        XCTAssertEqual(firstPortrait.x, portraitAfterLoop.x, accuracy: 0.0001)
        XCTAssertEqual(firstPortrait.y, portraitAfterLoop.y, accuracy: 0.0001)

        let firstLandscapeLeft = center(for: .landscapeLeft)
        _ = center(for: .landscapeRight)
        _ = center(for: .portraitUpsideDown)
        let landscapeLeftAfterOthers = center(for: .landscapeLeft)
        XCTAssertEqual(firstLandscapeLeft.x, landscapeLeftAfterOthers.x, accuracy: 0.0001)
        XCTAssertEqual(firstLandscapeLeft.y, landscapeLeftAfterOthers.y, accuracy: 0.0001)
    }

    func testGravityMapsToPhysicalDeviceOrientation() {
        XCTAssertEqual(
            CameraFullscreenPhysicalOrientation.orientation(gravityX: 0, gravityY: -1, gravityZ: 0),
            .portrait
        )
        XCTAssertEqual(
            CameraFullscreenPhysicalOrientation.orientation(gravityX: 0, gravityY: 1, gravityZ: 0),
            .portraitUpsideDown
        )
        XCTAssertEqual(
            CameraFullscreenPhysicalOrientation.orientation(gravityX: -1, gravityY: 0, gravityZ: 0),
            .landscapeLeft
        )
        XCTAssertEqual(
            CameraFullscreenPhysicalOrientation.orientation(gravityX: 1, gravityY: 0, gravityZ: 0),
            .landscapeRight
        )
        XCTAssertEqual(
            CameraFullscreenPhysicalOrientation.orientation(gravityX: 0, gravityY: 0, gravityZ: -1),
            .faceUp
        )
        XCTAssertEqual(
            CameraFullscreenPhysicalOrientation.orientation(gravityX: 0, gravityY: 0, gravityZ: 1),
            .faceDown
        )
    }

    func testGravityFaceUpKeepsLastValidWhenResolved() {
        XCTAssertEqual(
            CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(
                CameraFullscreenPhysicalOrientation.orientation(gravityX: 0, gravityY: 0, gravityZ: -1),
                lastValid: .portrait
            ),
            .portrait
        )
    }

    func testGravitySourceIsPhysicalIPadOnly() {
        XCTAssertTrue(
            CameraFullscreenPhysicalOrientation.usesGravitySource(
                userInterfaceIdiom: .pad,
                isDeviceMotionAvailable: true,
                isSimulator: false
            )
        )
        XCTAssertFalse(
            CameraFullscreenPhysicalOrientation.usesGravitySource(
                userInterfaceIdiom: .pad,
                isDeviceMotionAvailable: true,
                isSimulator: true
            )
        )
        XCTAssertFalse(
            CameraFullscreenPhysicalOrientation.usesGravitySource(
                userInterfaceIdiom: .phone,
                isDeviceMotionAvailable: true,
                isSimulator: false
            )
        )
        XCTAssertFalse(
            CameraFullscreenPhysicalOrientation.usesGravitySource(
                userInterfaceIdiom: .pad,
                isDeviceMotionAvailable: false,
                isSimulator: false
            )
        )
    }

    func testIPadLandscapeHostGeometryForFourPhysicalHolds() {
        let host = CGRect(x: 0, y: 0, width: 1366, height: 1024)
        let insets = UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0)
        let size = CGSize(width: 80, height: 40)

        func snapshot(_ orientation: UIDeviceOrientation) -> (corner: CameraFullscreenStatusOverlay.Corner, rotation: CGFloat, target: CGPoint, center: CGPoint) {
            let placement = CameraFullscreenStatusOverlay.placement(
                physicalOrientation: orientation,
                interfaceOrientation: .landscapeRight
            )
            let target = CameraFullscreenStatusOverlay.targetPoint(
                in: host,
                safeAreaInsets: insets,
                corner: placement.corner,
                topInset: 6,
                sideInset: 10
            )
            let center = CameraFullscreenStatusOverlay.overlayCenter(
                size: size,
                targetTopRight: target,
                rotationRadians: placement.rotationRadians
            )
            return (placement.corner, placement.rotationRadians, target, center)
        }

        let portrait = snapshot(.portrait)
        XCTAssertEqual(portrait.corner, .topLeft)
        XCTAssertEqual(portrait.target, CGPoint(x: 10, y: 30))

        let landscapeLeft = snapshot(.landscapeLeft)
        XCTAssertEqual(landscapeLeft.corner, .topRight)
        XCTAssertEqual(landscapeLeft.target, CGPoint(x: 1356, y: 30))

        let upsideDown = snapshot(.portraitUpsideDown)
        XCTAssertEqual(upsideDown.corner, .bottomRight)
        XCTAssertEqual(upsideDown.target, CGPoint(x: 1356, y: 998))

        let landscapeRight = snapshot(.landscapeRight)
        XCTAssertEqual(landscapeRight.corner, .bottomLeft)
        XCTAssertEqual(landscapeRight.target, CGPoint(x: 10, y: 998))

        XCTAssertNotEqual(portrait.center, landscapeLeft.center)
        XCTAssertNotEqual(landscapeLeft.center, landscapeRight.center)
        XCTAssertNotEqual(landscapeRight.center, upsideDown.center)
        XCTAssertNotEqual(upsideDown.center, portrait.center)
    }
}
