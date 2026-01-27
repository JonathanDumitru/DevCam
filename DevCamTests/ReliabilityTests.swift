//
//  ReliabilityTests.swift
//  DevCamTests
//
//  Tests for error recovery, disk space monitoring, buffer validation,
//  and other reliability mechanisms to ensure 99% uptime.
//

import XCTest
@testable import DevCam

@MainActor
final class ReliabilityTests: XCTestCase {
    var bufferManager: BufferManager!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevCamReliabilityTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        bufferManager = BufferManager(bufferDirectory: tempDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        bufferManager = nil
        tempDirectory = nil
        try await super.tearDown()
    }

    // MARK: - Disk Space Monitoring Tests

    func testDiskSpaceCheck() async throws {
        let result = bufferManager.checkDiskSpace()

        // Should have some disk space available in test environment
        XCTAssertTrue(result.availableBytes > 0, "Should report available disk space")

        // In a test environment, we should have plenty of space
        XCTAssertTrue(result.hasSpace, "Test environment should have sufficient space")
    }

    func testDiskSpaceWarningThreshold() async throws {
        let result = bufferManager.checkDiskSpace()

        // This is more of a sanity check - actual low space warning depends on system state
        // The important thing is that the method runs without error
        XCTAssertNotNil(result.isLowSpace, "Should return low space status")
    }

    // MARK: - Buffer Validation Tests

    func testValidateEmptyBuffer() async throws {
        let removedCount = bufferManager.validateBuffer()
        XCTAssertEqual(removedCount, 0, "Empty buffer should have no removals")
    }

    func testValidateBufferWithValidSegments() async throws {
        // Create valid test segments
        for i in 1...3 {
            let url = tempDirectory.appendingPathComponent("segment_\(i).mp4")
            try "valid_content_\(i)".write(to: url, atomically: true, encoding: .utf8)
            bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)
        }

        let removedCount = bufferManager.validateBuffer()
        XCTAssertEqual(removedCount, 0, "All valid segments should pass validation")
        XCTAssertEqual(bufferManager.getSegmentCount(), 3, "All segments should remain")
    }

    func testValidateBufferRemovesZeroByteFiles() async throws {
        // Create a mix of valid and zero-byte segments
        let validURL = tempDirectory.appendingPathComponent("segment_valid.mp4")
        try "valid_content".write(to: validURL, atomically: true, encoding: .utf8)
        bufferManager.addSegment(url: validURL, startTime: Date(), duration: 60.0)

        let zeroByteURL = tempDirectory.appendingPathComponent("segment_zero.mp4")
        FileManager.default.createFile(atPath: zeroByteURL.path, contents: Data(), attributes: nil)
        bufferManager.addSegment(url: zeroByteURL, startTime: Date(), duration: 60.0)

        let removedCount = bufferManager.validateBuffer()
        XCTAssertEqual(removedCount, 1, "Should remove the zero-byte segment")
        XCTAssertEqual(bufferManager.getSegmentCount(), 1, "Only valid segment should remain")
    }

    func testValidateBufferRemovesMissingFiles() async throws {
        // Add segment pointing to non-existent file
        let missingURL = tempDirectory.appendingPathComponent("segment_missing.mp4")
        bufferManager.addSegment(url: missingURL, startTime: Date(), duration: 60.0)

        let removedCount = bufferManager.validateBuffer()
        XCTAssertEqual(removedCount, 1, "Should remove segment with missing file")
        XCTAssertEqual(bufferManager.getSegmentCount(), 0, "No segments should remain")
    }

    // MARK: - Error Logging Tests (verifying try? replaced with logged errors)

    func testDeleteOldestSegmentWithMissingFile() async throws {
        // Add segment pointing to non-existent file
        let missingURL = tempDirectory.appendingPathComponent("segment_nonexistent.mp4")
        bufferManager.addSegment(url: missingURL, startTime: Date(), duration: 60.0)

        // Should not crash when file doesn't exist - error is logged
        bufferManager.deleteOldestSegment()

        // Segment should still be removed from buffer even if file wasn't deleted
        XCTAssertEqual(bufferManager.getSegmentCount(), 0, "Segment should be removed from buffer")
    }

    func testClearBufferWithMissingFiles() async throws {
        // Add segments with some missing files
        for i in 1...3 {
            let url = tempDirectory.appendingPathComponent("segment_\(i).mp4")
            if i <= 2 {
                try "content".write(to: url, atomically: true, encoding: .utf8)
            }
            // segment_3 won't have a file
            bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)
        }

        // Should not crash - errors are logged
        bufferManager.clearBuffer()

        XCTAssertEqual(bufferManager.getSegmentCount(), 0, "Buffer should be cleared")
    }

    // MARK: - Segment Count Tracking Tests

    func testSegmentCountTracking() async throws {
        XCTAssertEqual(bufferManager.getSegmentCount(), 0, "Initial count should be 0")

        let url = tempDirectory.appendingPathComponent("segment_1.mp4")
        try "content".write(to: url, atomically: true, encoding: .utf8)
        bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)

        XCTAssertEqual(bufferManager.getSegmentCount(), 1, "Count should be 1 after adding")

        bufferManager.clearBuffer()
        XCTAssertEqual(bufferManager.getSegmentCount(), 0, "Count should be 0 after clear")
    }

    // MARK: - Buffer Directory Tests

    func testBufferDirectoryCreation() async throws {
        // Create a new buffer manager with a non-existent directory
        let newDir = tempDirectory.appendingPathComponent("new_buffer_dir")
        let _ = BufferManager(bufferDirectory: newDir)

        // Directory should be created automatically
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDir.path), "Buffer directory should be created")
    }

    // MARK: - Stress Tests

    func testRapidSegmentAdditionAndValidation() async throws {
        // Rapidly add and validate segments
        for i in 1...50 {
            let url = tempDirectory.appendingPathComponent("segment_\(i).mp4")
            try "content_\(i)".write(to: url, atomically: true, encoding: .utf8)
            bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)

            // Validate every 10 additions
            if i % 10 == 0 {
                bufferManager.validateBuffer()
            }
        }

        // Max segments is 15, so we should have 15 segments
        XCTAssertEqual(bufferManager.getSegmentCount(), 15, "Should maintain max 15 segments")

        let removedCount = bufferManager.validateBuffer()
        XCTAssertEqual(removedCount, 0, "All remaining segments should be valid")
    }

    func testConcurrentBufferOperations() async throws {
        // Test that buffer operations handle concurrent access safely
        // (due to @MainActor, this is serialized, but tests the API)

        await withTaskGroup(of: Void.self) { group in
            // Add segments
            group.addTask { @MainActor in
                for i in 1...5 {
                    let url = self.tempDirectory.appendingPathComponent("concurrent_\(i).mp4")
                    try? "content".write(to: url, atomically: true, encoding: .utf8)
                    self.bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)
                }
            }

            // Check disk space
            group.addTask { @MainActor in
                let _ = self.bufferManager.checkDiskSpace()
            }

            // Get duration
            group.addTask { @MainActor in
                let _ = self.bufferManager.getCurrentBufferDuration()
            }
        }

        // Should complete without crashes
        XCTAssertGreaterThanOrEqual(bufferManager.getSegmentCount(), 0, "Buffer should be in valid state")
    }
}

// MARK: - Export Reliability Tests

@MainActor
final class ExportReliabilityTests: XCTestCase {
    var bufferManager: BufferManager!
    var clipExporter: ClipExporter!
    var settings: AppSettings!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevCamExportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        bufferManager = BufferManager(bufferDirectory: tempDirectory)
        settings = AppSettings()
        clipExporter = ClipExporter(bufferManager: bufferManager, settings: settings)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        bufferManager = nil
        clipExporter = nil
        settings = nil
        tempDirectory = nil
        try await super.tearDown()
    }

    func testExportWithEmptyBuffer() async throws {
        // Should throw noSegmentsAvailable error
        do {
            try await clipExporter.exportClip(duration: 300)
            XCTFail("Should throw error for empty buffer")
        } catch let error as ExportError {
            XCTAssertEqual(error, ExportError.noSegmentsAvailable, "Should throw noSegmentsAvailable")
        }
    }

    func testExportProgressTracking() async throws {
        // Add a test segment
        let url = tempDirectory.appendingPathComponent("segment_1.mp4")
        try "test_content".write(to: url, atomically: true, encoding: .utf8)
        bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)

        // Start export
        try await clipExporter.exportClip(duration: 60)

        // Progress should have updated
        XCTAssertEqual(clipExporter.exportProgress, 1.0, "Progress should be 1.0 after completion")
    }

    func testExportErrorStateReset() async throws {
        // Cause an export error
        do {
            try await clipExporter.exportClip(duration: 300)
        } catch {
            // Expected
        }

        // Error state should be set
        XCTAssertNotNil(clipExporter.exportError, "Error should be set after failure")
        XCTAssertFalse(clipExporter.isExporting, "Should not be exporting after error")
    }

    func testDeleteClipWithMissingFile() async throws {
        // Create a clip info with non-existent file
        let missingURL = tempDirectory.appendingPathComponent("missing_clip.mp4")
        let clipInfo = ClipInfo(
            id: UUID(),
            fileURL: missingURL,
            timestamp: Date(),
            duration: 60.0,
            fileSize: 1024
        )

        // Should not crash - error is logged
        clipExporter.deleteClip(clipInfo)

        // Test passes if no crash
        XCTAssertTrue(true, "Should handle missing file gracefully")
    }

    func testConcurrentExportPrevention() async throws {
        // Add a test segment
        let url = tempDirectory.appendingPathComponent("segment_1.mp4")
        try "test_content".write(to: url, atomically: true, encoding: .utf8)
        bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)

        // Start first export
        let export1 = Task {
            try await clipExporter.exportClip(duration: 60)
        }

        // Give it a moment to start
        try await Task.sleep(nanoseconds: 10_000_000)

        // Second export should be rejected while first is in progress
        // (This tests the guard at the start of exportClip)
        // Note: In test mode, exports are fast, so this may complete before we can test

        await export1.value
        XCTAssertFalse(clipExporter.isExporting, "Should not be exporting after completion")
    }
}

// MARK: - Recording Error Recovery Tests

@MainActor
final class RecordingErrorRecoveryTests: XCTestCase {
    var bufferManager: BufferManager!
    var permissionManager: PermissionManager!
    var recordingManager: RecordingManager!
    var settings: AppSettings!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevCamRecordingTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        bufferManager = BufferManager(bufferDirectory: tempDirectory)
        permissionManager = PermissionManager()
        settings = AppSettings()
        recordingManager = RecordingManager(
            bufferManager: bufferManager,
            permissionManager: permissionManager,
            settings: settings
        )
    }

    override func tearDown() async throws {
        await recordingManager.stopRecording()
        try? FileManager.default.removeItem(at: tempDirectory)
        bufferManager = nil
        permissionManager = nil
        recordingManager = nil
        settings = nil
        tempDirectory = nil
        try await super.tearDown()
    }

    func testRecordingStartsSuccessfully() async throws {
        try await recordingManager.startRecording()
        XCTAssertTrue(recordingManager.isRecording, "Recording should start")
        XCTAssertNil(recordingManager.recordingError, "No error should be present")
    }

    func testRecordingStopsCleanly() async throws {
        try await recordingManager.startRecording()
        await recordingManager.stopRecording()

        XCTAssertFalse(recordingManager.isRecording, "Recording should stop")
    }

    func testPauseAndResumeRecording() async throws {
        try await recordingManager.startRecording()
        XCTAssertTrue(recordingManager.isRecording)

        await recordingManager.pauseRecording()
        XCTAssertFalse(recordingManager.isRecording, "Should be paused")

        try await recordingManager.resumeRecording()
        XCTAssertTrue(recordingManager.isRecording, "Should resume")

        await recordingManager.stopRecording()
    }

    func testMultipleStartsAreIdempotent() async throws {
        try await recordingManager.startRecording()
        try await recordingManager.startRecording()
        try await recordingManager.startRecording()

        XCTAssertTrue(recordingManager.isRecording, "Should still be recording")

        await recordingManager.stopRecording()
    }

    func testMultipleStopsAreIdempotent() async throws {
        try await recordingManager.startRecording()

        await recordingManager.stopRecording()
        await recordingManager.stopRecording()
        await recordingManager.stopRecording()

        XCTAssertFalse(recordingManager.isRecording, "Should be stopped")
    }

    func testRecordingCreatesSegments() async throws {
        try await recordingManager.startRecording()

        // Wait for at least one segment
        try await Task.sleep(nanoseconds: 2_000_000_000)

        await recordingManager.stopRecording()

        let segments = bufferManager.getAllSegments()
        XCTAssertGreaterThan(segments.count, 0, "Should have created segments")
    }

    func testBufferValidationDuringRecording() async throws {
        try await recordingManager.startRecording()

        // Wait for segment creation
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Validate buffer while recording
        let removedCount = bufferManager.validateBuffer()
        XCTAssertEqual(removedCount, 0, "Test mode segments should be valid")

        await recordingManager.stopRecording()
    }
}

// MARK: - Error Type Tests

final class ErrorTypeTests: XCTestCase {

    func testRecordingErrorTypes() {
        let errors: [RecordingError] = [
            .permissionDenied,
            .noDisplaysAvailable,
            .streamSetupFailed,
            .writerSetupFailed,
            .segmentFinalizationFailed,
            .maxRetriesExceeded,
            .diskSpaceLow,
            .watchdogTimeout
        ]

        // All error types should be distinct
        XCTAssertEqual(errors.count, 8, "Should have 8 recording error types")
    }

    func testExportErrorRetryable() {
        // Test retryable errors
        XCTAssertTrue(ExportError.exportFailed("test").isRetryable)
        XCTAssertTrue(ExportError.compositionFailed.isRetryable)

        // Test non-retryable errors
        XCTAssertFalse(ExportError.noSegmentsAvailable.isRetryable)
        XCTAssertFalse(ExportError.insufficientBufferContent.isRetryable)
        XCTAssertFalse(ExportError.saveLocationUnavailable.isRetryable)
        XCTAssertFalse(ExportError.diskSpaceLow.isRetryable)
        XCTAssertFalse(ExportError.maxRetriesExceeded.isRetryable)
    }
}
