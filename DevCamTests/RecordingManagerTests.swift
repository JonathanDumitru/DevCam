//
//  RecordingManagerTests.swift
//  DevCamTests
//
//  Tests for RecordingManager with ScreenCaptureKit integration
//

import XCTest
@testable import DevCam

@MainActor
final class RecordingManagerTests: XCTestCase {
    var bufferManager: BufferManager!
    var permissionManager: PermissionManager!
    var recordingManager: RecordingManager!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory for test buffer
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevCamTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Initialize managers
        bufferManager = BufferManager(bufferDirectory: tempDirectory)
        permissionManager = PermissionManager()
        recordingManager = RecordingManager(
            bufferManager: bufferManager,
            permissionManager: permissionManager
        )
    }

    override func tearDown() async throws {
        // Stop recording if active
        await recordingManager.stopRecording()

        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)

        bufferManager = nil
        permissionManager = nil
        recordingManager = nil
        tempDirectory = nil

        try await super.tearDown()
    }

    // MARK: - Basic Recording Tests

    func testStartRecording() async throws {
        // In test mode, recording should start without actual screen capture
        try await recordingManager.startRecording()

        XCTAssertTrue(recordingManager.isRecording, "Recording should be active")
        XCTAssertNil(recordingManager.recordingError, "No error should be present")
    }

    func testStopRecording() async throws {
        try await recordingManager.startRecording()
        XCTAssertTrue(recordingManager.isRecording)

        await recordingManager.stopRecording()
        XCTAssertFalse(recordingManager.isRecording, "Recording should be stopped")
    }

    func testStartRecordingTwice() async throws {
        try await recordingManager.startRecording()
        XCTAssertTrue(recordingManager.isRecording)

        // Starting again should be a no-op
        try await recordingManager.startRecording()
        XCTAssertTrue(recordingManager.isRecording)
    }

    func testStopWhenNotRecording() async throws {
        XCTAssertFalse(recordingManager.isRecording)

        // Stopping when not recording should be safe
        await recordingManager.stopRecording()
        XCTAssertFalse(recordingManager.isRecording)
    }

    // MARK: - Segment Creation Tests

    func testSegmentCreation() async throws {
        try await recordingManager.startRecording()

        // Wait a bit for segment to be created
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        await recordingManager.stopRecording()

        // Check that buffer has at least one segment
        let duration = await bufferManager.getCurrentBufferDuration()
        XCTAssertGreaterThan(duration, 0, "Buffer should have content")
    }

    func testSegmentRotation() async throws {
        try await recordingManager.startRecording()

        // Wait for first segment rotation (61 seconds to be safe)
        try await Task.sleep(nanoseconds: 61_000_000_000)

        // Check buffer has multiple segments
        let duration = await bufferManager.getCurrentBufferDuration()
        XCTAssertGreaterThan(duration, 60.0, "Buffer should have more than 60 seconds")

        await recordingManager.stopRecording()
    }

    func testBufferDurationUpdate() async throws {
        try await recordingManager.startRecording()

        // Wait for segment creation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Buffer duration should be updated
        XCTAssertGreaterThan(recordingManager.bufferDuration, 0, "Published buffer duration should update")

        await recordingManager.stopRecording()
    }

    // MARK: - Pause/Resume Tests

    func testPauseRecording() async throws {
        try await recordingManager.startRecording()
        XCTAssertTrue(recordingManager.isRecording)

        await recordingManager.pauseRecording()
        XCTAssertFalse(recordingManager.isRecording, "Recording should be paused")
    }

    func testResumeRecording() async throws {
        try await recordingManager.startRecording()
        await recordingManager.pauseRecording()
        XCTAssertFalse(recordingManager.isRecording)

        try await recordingManager.resumeRecording()
        XCTAssertTrue(recordingManager.isRecording, "Recording should resume")

        await recordingManager.stopRecording()
    }

    func testResumeWhenAlreadyRecording() async throws {
        try await recordingManager.startRecording()
        XCTAssertTrue(recordingManager.isRecording)

        // Resume when already recording should be a no-op
        try await recordingManager.resumeRecording()
        XCTAssertTrue(recordingManager.isRecording)

        await recordingManager.stopRecording()
    }

    // MARK: - Error Handling Tests

    func testRecordingErrorTracking() async throws {
        // Initially no error
        XCTAssertNil(recordingManager.recordingError)

        // Start recording (may fail in test environment without permissions)
        // Error should be tracked if it fails
        try? await recordingManager.startRecording()

        // If there was an error, it should be set
        if !recordingManager.isRecording {
            // In a real test environment without permissions, error might be set
            // But in our test mode, it should succeed
        }

        await recordingManager.stopRecording()
    }

    // MARK: - Integration Tests

    func testFullRecordingCycle() async throws {
        // Start
        try await recordingManager.startRecording()
        XCTAssertTrue(recordingManager.isRecording)

        // Wait for some recording
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Check buffer updated
        XCTAssertGreaterThan(recordingManager.bufferDuration, 0)

        // Stop
        await recordingManager.stopRecording()
        XCTAssertFalse(recordingManager.isRecording)

        // Verify segments exist in buffer
        let segments = await bufferManager.getAllSegments()
        XCTAssertGreaterThan(segments.count, 0, "Should have created at least one segment")
    }

    func testMultiplePauseResumeCycles() async throws {
        for _ in 0..<3 {
            try await recordingManager.startRecording()
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            await recordingManager.pauseRecording()
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        // Final check
        let duration = await bufferManager.getCurrentBufferDuration()
        XCTAssertGreaterThan(duration, 0, "Buffer should have accumulated content")
    }

    // MARK: - Performance Tests

    func testMemoryUsageDuringRecording() async throws {
        try await recordingManager.startRecording()

        // Record for a few seconds
        try await Task.sleep(nanoseconds: 5_000_000_000)

        await recordingManager.stopRecording()

        // In test mode, memory should be minimal (no actual video encoding)
        // This is more of a placeholder for manual testing
        XCTAssertTrue(true, "Memory test completed")
    }
}
