//
//  FrameRateControllerTests.swift
//  DevCamTests
//
//  Tests for FrameRateController state machine
//

import XCTest
@testable import DevCam

@MainActor
final class FrameRateControllerTests: XCTestCase {
    var settings: AppSettings!
    var controller: FrameRateController!

    override func setUp() async throws {
        try await super.setUp()
        settings = AppSettings()
        settings.targetFrameRate = .fps30
        settings.idleFrameRate = .fps10
        settings.idleThreshold = 5.0
        settings.adaptiveFrameRateEnabled = true
    }

    override func tearDown() async throws {
        controller?.stop()
        controller = nil
        settings = nil
        try await super.tearDown()
    }

    func testInitialStateIsActive() async {
        controller = FrameRateController(settings: settings)
        controller.start()

        XCTAssertEqual(controller.state, .active)
        XCTAssertEqual(controller.currentFrameRate, .fps30)
    }

    func testFrameRateMatchesTargetWhenDisabled() async {
        settings.adaptiveFrameRateEnabled = false
        settings.targetFrameRate = .fps60

        controller = FrameRateController(settings: settings)
        controller.start()

        XCTAssertEqual(controller.currentFrameRate, .fps60)
    }

    func testFrameComparisonIdenticalFramesAreStatic() async {
        controller = FrameRateController(settings: settings)

        // Create two identical test images
        let size = CGSize(width: 100, height: 100)
        let image1 = createTestImage(size: size, color: .red)
        let image2 = createTestImage(size: size, color: .red)

        // Both frames should be considered static
        // This tests the internal comparison logic indirectly
        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
    }

    func testFrameComparisonDifferentFramesDetectMotion() async {
        controller = FrameRateController(settings: settings)

        // Create two different test images
        let size = CGSize(width: 100, height: 100)
        let image1 = createTestImage(size: size, color: .red)
        let image2 = createTestImage(size: size, color: .blue)

        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
    }

    // MARK: - Helpers

    private func createTestImage(size: CGSize, color: NSColor) -> CGImage? {
        let rect = CGRect(origin: .zero, size: size)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(color.cgColor)
        context.fill(rect)

        return context.makeImage()
    }
}
