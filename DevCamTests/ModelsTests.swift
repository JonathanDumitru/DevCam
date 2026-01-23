import XCTest
@testable import DevCam

final class ModelsTests: XCTestCase {

    func testSegmentInfoCreation() {
        let url = URL(fileURLWithPath: "/tmp/segment_001.mp4")
        let startTime = Date()
        let duration: TimeInterval = 60.0

        let segment = SegmentInfo(
            id: UUID(),
            fileURL: url,
            startTime: startTime,
            duration: duration
        )

        XCTAssertEqual(segment.fileURL, url)
        XCTAssertEqual(segment.startTime, startTime)
        XCTAssertEqual(segment.duration, 60.0)
        XCTAssertEqual(segment.endTime, startTime.addingTimeInterval(60.0))
    }

    func testClipInfoCreation() {
        let url = URL(fileURLWithPath: "/tmp/clip_001.mp4")
        let timestamp = Date()
        let duration: TimeInterval = 600.0

        let clip = ClipInfo(
            id: UUID(),
            fileURL: url,
            timestamp: timestamp,
            duration: duration,
            fileSize: 50_000_000
        )

        XCTAssertEqual(clip.fileURL, url)
        XCTAssertEqual(clip.timestamp, timestamp)
        XCTAssertEqual(clip.duration, 600.0)
        XCTAssertEqual(clip.fileSize, 50_000_000)
    }

    func testClipInfoFileSizeFormatting() {
        let clip = ClipInfo(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            timestamp: Date(),
            duration: 60,
            fileSize: 52_428_800 // 50 MB
        )

        XCTAssertEqual(clip.fileSizeFormatted, "50.0 MB")
    }
}
