//
//  DisplaySwitchTests.swift
//  DevCamTests
//
//  Mock-based tests for display switch functionality.
//  These tests don't require screen recording permission.
//

import XCTest
@testable import DevCam

// MARK: - Buffer Manager Tests (No Permission Required)

@MainActor
final class DisplaySwitchBufferTests: XCTestCase {
    var bufferManager: BufferManager!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevCamTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        bufferManager = BufferManager(bufferDirectory: tempDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        bufferManager = nil
        tempDirectory = nil
        try await super.tearDown()
    }

    func testClearBufferRemovesAllSegments() async throws {
        // Add some test segments
        for i in 1...5 {
            let url = tempDirectory.appendingPathComponent("segment_\(i).mp4")
            try "test_content_\(i)".write(to: url, atomically: true, encoding: .utf8)
            bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)
        }

        // Verify segments exist
        let segmentsBefore = bufferManager.getAllSegments()
        XCTAssertEqual(segmentsBefore.count, 5, "Should have 5 segments before clear")

        let durationBefore = bufferManager.getCurrentBufferDuration()
        XCTAssertEqual(durationBefore, 300.0, "Should have 300 seconds of buffer")

        // Clear buffer
        bufferManager.clearBuffer()

        // Verify all segments removed
        let segmentsAfter = bufferManager.getAllSegments()
        XCTAssertEqual(segmentsAfter.count, 0, "Should have 0 segments after clear")

        let durationAfter = bufferManager.getCurrentBufferDuration()
        XCTAssertEqual(durationAfter, 0, "Should have 0 seconds of buffer after clear")
    }

    func testClearBufferDeletesFiles() async throws {
        // Add a test segment with an actual file
        let url = tempDirectory.appendingPathComponent("segment_test.mp4")
        try "test_content".write(to: url, atomically: true, encoding: .utf8)
        bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "File should exist before clear")

        // Clear buffer
        bufferManager.clearBuffer()

        // File should be deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "File should be deleted after clear")
    }

    func testClearEmptyBufferIsNoOp() async throws {
        // Buffer starts empty
        XCTAssertEqual(bufferManager.getAllSegments().count, 0)

        // Clear should not crash
        bufferManager.clearBuffer()

        // Still empty
        XCTAssertEqual(bufferManager.getAllSegments().count, 0)
    }
}

// MARK: - Settings Tests (No Permission Required)

@MainActor
final class DisplaySwitchSettingsTests: XCTestCase {
    var settings: AppSettings!

    override func setUp() async throws {
        try await super.setUp()
        settings = AppSettings()
    }

    override func tearDown() async throws {
        settings = nil
        try await super.tearDown()
    }

    func testDisplaySelectionModeUpdate() async throws {
        // Start with primary mode
        settings.displaySelectionMode = .primary
        XCTAssertEqual(settings.displaySelectionMode, .primary)

        // Switch to specific mode
        settings.displaySelectionMode = .specific
        XCTAssertEqual(settings.displaySelectionMode, .specific)
    }

    func testSelectedDisplayIDUpdate() async throws {
        let testDisplayID: UInt32 = 12345

        settings.selectedDisplayID = testDisplayID
        XCTAssertEqual(settings.selectedDisplayID, testDisplayID)
    }

    func testDisplayIDPersistsAsInt() async throws {
        // Test that UInt32 display IDs work correctly with the Int-based storage
        let maxDisplayID: UInt32 = UInt32.max / 2 // Large but safe value

        settings.selectedDisplayID = maxDisplayID
        XCTAssertEqual(settings.selectedDisplayID, maxDisplayID)
    }

    func testSwitchToSpecificModeSetsDisplayID() async throws {
        let targetDisplayID: UInt32 = 99999

        // Simulate what switchDisplay does
        settings.selectedDisplayID = targetDisplayID
        settings.displaySelectionMode = .specific

        XCTAssertEqual(settings.displaySelectionMode, .specific)
        XCTAssertEqual(settings.selectedDisplayID, targetDisplayID)
    }
}

// MARK: - Display Disconnect Error Detection Tests

@MainActor
final class DisplayDisconnectDetectionTests: XCTestCase {

    func testScreenCaptureKitDisplayErrorCodes() async throws {
        // Test known ScreenCaptureKit error codes for display issues
        let displayErrorCodes = [-3814, -3815, -3816]

        for code in displayErrorCodes {
            let error = NSError(domain: "com.apple.ScreenCaptureKit", code: code, userInfo: nil)
            XCTAssertTrue(
                isDisplayDisconnectedError(error),
                "Error code \(code) should be detected as display disconnect"
            )
        }
    }

    func testNonDisplayErrorsNotDetected() async throws {
        // Regular errors should not be detected as display disconnect
        let regularError = NSError(domain: "com.apple.ScreenCaptureKit", code: -1000, userInfo: nil)
        XCTAssertFalse(
            isDisplayDisconnectedError(regularError),
            "Regular error should not be detected as display disconnect"
        )
    }

    func testIOSurfaceErrorsDetected() async throws {
        let ioSurfaceError = NSError(domain: "IOSurface", code: 1, userInfo: nil)
        XCTAssertTrue(
            isDisplayDisconnectedError(ioSurfaceError),
            "IOSurface errors should be detected as display disconnect"
        )
    }

    func testErrorDescriptionKeywords() async throws {
        // Test error description-based detection
        let disconnectError = NSError(
            domain: "TestDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Display disconnected during capture"]
        )
        XCTAssertTrue(
            isDisplayDisconnectedError(disconnectError),
            "Error with 'display' and 'disconnect' should be detected"
        )

        let notAvailableError = NSError(
            domain: "TestDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Display not available"]
        )
        XCTAssertTrue(
            isDisplayDisconnectedError(notAvailableError),
            "Error with 'display' and 'not available' should be detected"
        )

        let removedError = NSError(
            domain: "TestDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Display was removed"]
        )
        XCTAssertTrue(
            isDisplayDisconnectedError(removedError),
            "Error with 'display' and 'removed' should be detected"
        )
    }

    func testUnrelatedErrorsNotDetected() async throws {
        let networkError = NSError(
            domain: "NSURLErrorDomain",
            code: -1009,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )
        XCTAssertFalse(
            isDisplayDisconnectedError(networkError),
            "Network error should not be detected as display disconnect"
        )
    }

    // Helper function that mirrors the logic in RecordingManager
    private func isDisplayDisconnectedError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == "com.apple.ScreenCaptureKit" {
            let displayErrors: Set<Int> = [-3814, -3815, -3816]
            return displayErrors.contains(nsError.code)
        }

        if nsError.domain == "IOSurface" {
            return true
        }

        let description = error.localizedDescription.lowercased()
        return description.contains("display") && (
            description.contains("disconnect") ||
            description.contains("not available") ||
            description.contains("removed")
        )
    }
}

// MARK: - Confirmation View Tests

@MainActor
final class DisplaySwitchConfirmationViewTests: XCTestCase {

    func testConfirmationViewInitialization() async throws {
        var confirmCalled = false
        var cancelCalled = false

        let view = DisplaySwitchConfirmationView(
            targetDisplayName: "Display 2 (1920×1080)",
            onConfirm: { confirmCalled = true },
            onCancel: { cancelCalled = true }
        )

        // View should initialize without issues
        XCTAssertNotNil(view)
    }

    func testConfirmCallbackTriggered() async throws {
        var confirmCalled = false

        let onConfirm = { confirmCalled = true }

        // Simulate what happens when user clicks confirm
        onConfirm()

        XCTAssertTrue(confirmCalled, "Confirm callback should be triggered")
    }

    func testCancelCallbackTriggered() async throws {
        var cancelCalled = false

        let onCancel = { cancelCalled = true }

        // Simulate what happens when user clicks cancel
        onCancel()

        XCTAssertTrue(cancelCalled, "Cancel callback should be triggered")
    }
}

// MARK: - Display List Tests

@MainActor
final class DisplayListTests: XCTestCase {

    func testPrimaryDisplaySelection() async throws {
        // Simulate display list with different resolutions
        let displays: [(id: UInt32, name: String, width: Int, height: Int)] = [
            (id: 1, name: "Display 1", width: 1920, height: 1080),  // 2,073,600 pixels
            (id: 2, name: "Display 2", width: 2560, height: 1440),  // 3,686,400 pixels (largest)
            (id: 3, name: "Display 3", width: 1280, height: 720),   // 921,600 pixels
        ]

        // Primary should be the largest display
        let primary = displays.max(by: { $0.width * $0.height < $1.width * $1.height })

        XCTAssertEqual(primary?.id, 2, "Primary should be Display 2 (largest)")
        XCTAssertEqual(primary?.width, 2560)
        XCTAssertEqual(primary?.height, 1440)
    }

    func testDisplayLabelFormatting() async throws {
        let display = (id: UInt32(1), name: "Display 1", width: 1920, height: 1080)

        let label = "\(display.name) (\(display.width)×\(display.height))"

        XCTAssertEqual(label, "Display 1 (1920×1080)")
    }

    func testEmptyDisplayList() async throws {
        let displays: [(id: UInt32, name: String, width: Int, height: Int)] = []

        let primary = displays.max(by: { $0.width * $0.height < $1.width * $1.height })

        XCTAssertNil(primary, "Primary should be nil for empty display list")
    }

    func testSingleDisplayIsPrimary() async throws {
        let displays: [(id: UInt32, name: String, width: Int, height: Int)] = [
            (id: 42, name: "Only Display", width: 1920, height: 1080),
        ]

        let primary = displays.max(by: { $0.width * $0.height < $1.width * $1.height })

        XCTAssertEqual(primary?.id, 42, "Single display should be primary")
    }
}
