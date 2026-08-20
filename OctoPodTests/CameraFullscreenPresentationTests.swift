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

    func testClockwiseRotationOrientationTable() {
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Clockwise(.up), .right)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Clockwise(.right), .down)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Clockwise(.down), .left)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Clockwise(.left), .up)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Clockwise(.upMirrored), .rightMirrored)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Clockwise(.rightMirrored), .downMirrored)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Clockwise(.downMirrored), .leftMirrored)
        XCTAssertEqual(CameraFullscreenPresentation.orientationByRotating90Clockwise(.leftMirrored), .upMirrored)
    }

    func testRepeatedRotationIsNotIdempotentWithoutRestore() {
        let twice = CameraFullscreenPresentation.orientationByRotating90Clockwise(
            CameraFullscreenPresentation.orientationByRotating90Clockwise(.up)
        )
        XCTAssertEqual(twice, .down)
        XCTAssertNotEqual(twice, CameraFullscreenPresentation.orientationByRotating90Clockwise(.up))
    }

    func testFullscreenRotationTurnsPortraitDisplayIntoLandscapeWithoutChangingPixels() {
        let image = makeImage(width: 736, height: 1312, orientation: .up)
        XCTAssertTrue(CameraFullscreenPresentation.isPortraitDisplay(image.size))

        let fullscreenOrientation = CameraFullscreenPresentation.orientationByRotating90Clockwise(image.imageOrientation)
        let fullscreenImage = CameraFullscreenPresentation.imageByReplacingOrientation(image, orientation: fullscreenOrientation)

        XCTAssertEqual(fullscreenImage.size, CGSize(width: 1312, height: 736))
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(fullscreenImage.size))
        XCTAssertEqual(fullscreenImage.cgImage?.width, image.cgImage?.width)
        XCTAssertEqual(fullscreenImage.cgImage?.height, image.cgImage?.height)
        XCTAssertEqual(fullscreenImage.size.width / fullscreenImage.size.height, image.size.height / image.size.width, accuracy: 0.0001)
    }

    func testOctoPrintRotate90PortraitDisplayBecomesLandscapeAfterFullscreenRotation() {
        let image = makeImage(width: 1312, height: 736, orientation: .left)
        XCTAssertEqual(image.size, CGSize(width: 736, height: 1312))
        XCTAssertTrue(CameraFullscreenPresentation.isPortraitDisplay(image.size))

        let fullscreenImage = CameraFullscreenPresentation.imageByReplacingOrientation(
            image,
            orientation: CameraFullscreenPresentation.orientationByRotating90Clockwise(image.imageOrientation)
        )
        XCTAssertEqual(fullscreenImage.size, CGSize(width: 1312, height: 736))
        XCTAssertFalse(CameraFullscreenPresentation.isPortraitDisplay(fullscreenImage.size))
    }

    func testReplacingOrientationRestoresEmbeddedPresentation() {
        let original = makeImage(width: 736, height: 1312, orientation: .up)
        let fullscreenImage = CameraFullscreenPresentation.imageByReplacingOrientation(
            original,
            orientation: CameraFullscreenPresentation.orientationByRotating90Clockwise(original.imageOrientation)
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
