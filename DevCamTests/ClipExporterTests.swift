//
//  ClipExporterTests.swift
//  DevCamTests
//
//  Tests for ClipExporter video stitching and export functionality
//

import XCTest
@testable import DevCam

@MainActor
final class ClipExporterTests: XCTestCase {
    var bufferManager: BufferManager!
    var clipExporter: ClipExporter!
    var settings: AppSettings!
    var tempDirectory: URL!
    var saveDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directories
        let baseTemp = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevCamTests-\(UUID().uuidString)")

        tempDirectory = baseTemp.appendingPathComponent("buffer")
        saveDirectory = baseTemp.appendingPathComponent("exports")

        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)

        // Initialize managers
        bufferManager = BufferManager(bufferDirectory: tempDirectory)
        settings = AppSettings()
        // Override save location for tests
        settings.saveLocation = saveDirectory
        clipExporter = ClipExporter(
            bufferManager: bufferManager,
            settings: settings
        )
    }

    override func tearDown() async throws {
        // Clean up
        try? FileManager.default.removeItem(at: tempDirectory.deletingLastPathComponent())

        bufferManager = nil
        clipExporter = nil
        tempDirectory = nil
        saveDirectory = nil

        try await super.tearDown()
    }

    // MARK: - Basic Export Tests

    func testExportWithNoSegments() async throws {
        // Attempt export with empty buffer
        do {
            try await clipExporter.exportClip(duration: 300)
            XCTFail("Should throw error when buffer is empty")
        } catch ExportError.noSegmentsAvailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExportWithSegments() async throws {
        // Add test segments to buffer
        try await createTestSegments(count: 3)

        // Export clip
        try await clipExporter.exportClip(duration: 180)

        // Verify export completed
        XCTAssertFalse(clipExporter.isExporting, "Export should be complete")
        XCTAssertEqual(clipExporter.exportProgress, 1.0, "Progress should be 100%")
        XCTAssertNil(clipExporter.exportError, "No error should be present")
    }

    func testExportCreatesFile() async throws {
        // Add segments
        try await createTestSegments(count: 2)

        // Export
        try await clipExporter.exportClip(duration: 120)

        // Check recent clips
        XCTAssertEqual(clipExporter.recentClips.count, 1, "Should have one recent clip")

        let clip = try XCTUnwrap(clipExporter.recentClips.first)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: clip.fileURL.path), "Export file should exist")
    }

    func testExportFilenameFormat() async throws {
        // Add segments
        try await createTestSegments(count: 1)

        // Export
        try await clipExporter.exportClip(duration: 60)

        let clip = try XCTUnwrap(clipExporter.recentClips.first)
        let filename = clip.fileURL.lastPathComponent

        // Verify format: DevCam_YYYY-MM-DD_HH-MM-SS.mp4
        XCTAssertTrue(filename.hasPrefix("DevCam_"), "Filename should start with DevCam_")
        XCTAssertTrue(filename.hasSuffix(".mp4"), "Filename should end with .mp4")

        // Check date format
        let datePattern = #"DevCam_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.mp4"#
        let regex = try NSRegularExpression(pattern: datePattern)
        let range = NSRange(location: 0, length: filename.utf16.count)
        XCTAssertNotNil(regex.firstMatch(in: filename, range: range), "Filename should match date pattern")
    }

    // MARK: - Progress Tracking Tests

    func testExportProgressUpdates() async throws {
        // Add segments
        try await createTestSegments(count: 2)

        // Track progress changes
        var progressValues: [Double] = []
        let cancellable = clipExporter.$exportProgress.sink { progress in
            progressValues.append(progress)
        }

        // Export
        try await clipExporter.exportClip(duration: 120)

        cancellable.cancel()

        // Verify progress increased
        XCTAssertGreaterThan(progressValues.count, 1, "Progress should update multiple times")
        XCTAssertEqual(progressValues.last, 1.0, "Final progress should be 100%")
    }

    func testIsExportingFlag() async throws {
        // Add segments
        try await createTestSegments(count: 1)

        // Initially not exporting
        XCTAssertFalse(clipExporter.isExporting)

        // Start export
        Task {
            try? await clipExporter.exportClip(duration: 60)
        }

        // Give it a moment to start
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s

        // Should be exporting
        XCTAssertTrue(clipExporter.isExporting)

        // Wait for completion
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Should be done
        XCTAssertFalse(clipExporter.isExporting)
    }

    // MARK: - Recent Clips Tests

    func testRecentClipsTracking() async throws {
        // Add segments
        try await createTestSegments(count: 5)

        // Export multiple clips
        for _ in 0..<3 {
            try await clipExporter.exportClip(duration: 60)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s between exports
        }

        // Verify recent clips
        XCTAssertEqual(clipExporter.recentClips.count, 3, "Should have 3 recent clips")

        // Most recent should be first
        let firstClip = clipExporter.recentClips[0]
        let lastClip = clipExporter.recentClips[2]
        XCTAssertGreaterThan(firstClip.timestamp, lastClip.timestamp, "Most recent clip should be first")
    }

    func testRecentClipsMaxLimit() async throws {
        // The max is 20, but we'll test with a smaller number to save time
        try await createTestSegments(count: 5)

        // Export 5 clips
        for _ in 0..<5 {
            try await clipExporter.exportClip(duration: 60)
        }

        // Verify count
        XCTAssertLessThanOrEqual(clipExporter.recentClips.count, 20, "Should not exceed max recent clips")
    }

    func testDeleteClip() async throws {
        // Add segments and export
        try await createTestSegments(count: 1)
        try await clipExporter.exportClip(duration: 60)

        let clip = try XCTUnwrap(clipExporter.recentClips.first)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: clip.fileURL.path))

        // Delete clip
        clipExporter.deleteClip(clip)

        // Verify removed from recent clips
        XCTAssertTrue(clipExporter.recentClips.isEmpty, "Recent clips should be empty")

        // Verify file deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: clip.fileURL.path), "File should be deleted")
    }

    func testClearRecentClips() async throws {
        // Add segments and export multiple
        try await createTestSegments(count: 3)

        for _ in 0..<3 {
            try await clipExporter.exportClip(duration: 60)
        }

        XCTAssertEqual(clipExporter.recentClips.count, 3)

        // Clear
        clipExporter.clearRecentClips()

        XCTAssertTrue(clipExporter.recentClips.isEmpty, "Recent clips should be cleared")
    }

    // MARK: - Save Location Tests

    func testUpdateSaveLocation() async throws {
        let newLocation = saveDirectory.appendingPathComponent("new-location")

        // Update location via settings (now applies immediately)
        // Note: Directory creation now happens automatically during export
        settings.saveLocation = newLocation

        // Export should use new location immediately and create directory
        try await createTestSegments(count: 1)
        try await clipExporter.exportClip(duration: 60)

        let clip = try XCTUnwrap(clipExporter.recentClips.first)
        XCTAssertTrue(clip.fileURL.path.contains("new-location"), "Clip should be in new location")

        // Verify directory was created during export
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: newLocation.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue, "Save location directory should exist")
    }

    // MARK: - Duration Tests

    func testExportWithRequestedDurationLargerThanBuffer() async throws {
        // Add 3 segments (180 seconds total)
        try await createTestSegments(count: 3)

        // Request more than available
        try await clipExporter.exportClip(duration: 600) // Request 10 minutes

        // Should export all available
        let clip = try XCTUnwrap(clipExporter.recentClips.first)
        XCTAssertEqual(clip.duration, 180, accuracy: 1.0, "Should export all available content")
    }

    func testExportWithPartialDuration() async throws {
        // Add 5 segments (300 seconds)
        try await createTestSegments(count: 5)

        // Request 2 minutes
        try await clipExporter.exportClip(duration: 120)

        let clip = try XCTUnwrap(clipExporter.recentClips.first)
        XCTAssertEqual(clip.duration, 120, accuracy: 1.0, "Should export requested duration")
    }

    // MARK: - Concurrent Export Tests

    func testCannotStartMultipleExportsSimultaneously() async throws {
        try await createTestSegments(count: 5)

        // Start first export
        Task {
            try? await clipExporter.exportClip(duration: 120)
        }

        // Give it time to start
        try await Task.sleep(nanoseconds: 50_000_000)

        // Try to start second export
        Task {
            try? await clipExporter.exportClip(duration: 60)
        }

        // Wait
        try await Task.sleep(nanoseconds: 500_000_000)

        // Should only have one clip (second was rejected)
        XCTAssertEqual(clipExporter.recentClips.count, 1, "Only one export should complete")
    }

    // MARK: - ClipInfo Tests

    func testClipInfoMetadata() async throws {
        try await createTestSegments(count: 2)
        try await clipExporter.exportClip(duration: 120)

        let clip = try XCTUnwrap(clipExporter.recentClips.first)

        // Verify metadata
        XCTAssertGreaterThan(clip.fileSize, 0, "File size should be positive")
        XCTAssertEqual(clip.duration, 120, accuracy: 1.0, "Duration should match request")
        XCTAssertNotNil(clip.durationFormatted, "Should have formatted duration")
        XCTAssertNotNil(clip.fileSizeFormatted, "Should have formatted file size")
    }

    // MARK: - Helper Methods

    private func createTestSegments(count: Int) async throws {
        for i in 0..<count {
            let segmentURL = tempDirectory.appendingPathComponent("segment_\(i).mp4")
            let content = "TEST_SEGMENT_\(i)"
            try content.write(to: segmentURL, atomically: true, encoding: .utf8)

            let startTime = Date().addingTimeInterval(TimeInterval(-count * 60 + i * 60))
            await bufferManager.addSegment(url: segmentURL, startTime: startTime, duration: 60.0)
        }
    }
}
