import XCTest
@testable import DevCam

final class BufferManagerTests: XCTestCase {
    var bufferManager: BufferManager!
    var tempDirectory: URL!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        bufferManager = await BufferManager(bufferDirectory: tempDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testAddSegment() async throws {
        let url = tempDirectory.appendingPathComponent("segment_001.mp4")
        try "test".write(to: url, atomically: true, encoding: .utf8)

        await bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)

        let duration = await bufferManager.getCurrentBufferDuration()
        XCTAssertEqual(duration, 60.0)
    }

    func testSegmentRotation() async throws {
        // Add 16 segments - should delete oldest automatically
        for i in 1...16 {
            let url = tempDirectory.appendingPathComponent("segment_\(String(format: "%03d", i)).mp4")
            try "test".write(to: url, atomically: true, encoding: .utf8)
            await bufferManager.addSegment(url: url, startTime: Date(), duration: 60.0)
        }

        let segments = await bufferManager.getAllSegments()
        XCTAssertEqual(segments.count, 15, "Should only keep 15 segments (15 minutes)")

        // First segment should be deleted
        let firstSegmentURL = tempDirectory.appendingPathComponent("segment_001.mp4")
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstSegmentURL.path))
    }

    func testGetSegmentsForTimeRange() async throws {
        let baseTime = Date()

        // Add 10 segments
        for i in 1...10 {
            let url = tempDirectory.appendingPathComponent("segment_\(String(format: "%03d", i)).mp4")
            try "test".write(to: url, atomically: true, encoding: .utf8)
            let startTime = baseTime.addingTimeInterval(Double((i-1) * 60))
            await bufferManager.addSegment(url: url, startTime: startTime, duration: 60.0)
        }

        // Request last 5 minutes (300 seconds)
        let segments = await bufferManager.getSegmentsForTimeRange(duration: 300.0)

        XCTAssertEqual(segments.count, 5, "Should return 5 segments for 5 minutes")
    }
}
