import Foundation
import OSLog

@MainActor
class BufferManager {
    private var segments: [SegmentInfo] = []
    private let bufferDirectory: URL
    private let maxSegments = 15 // 15 minutes at 1 minute per segment

    init(bufferDirectory: URL? = nil) {
        if let directory = bufferDirectory {
            self.bufferDirectory = directory
        } else {
            // Default: ~/Library/Application Support/DevCam/buffer/
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.bufferDirectory = appSupport.appendingPathComponent("DevCam/buffer")
        }

        // Create directory if needed
        try? FileManager.default.createDirectory(at: self.bufferDirectory, withIntermediateDirectories: true)
    }

    func addSegment(url: URL, startTime: Date, duration: TimeInterval) {
        let segment = SegmentInfo(
            id: UUID(),
            fileURL: url,
            startTime: startTime,
            duration: duration
        )

        segments.append(segment)

        // Rotate if we exceed max segments
        if segments.count > maxSegments {
            deleteOldestSegment()
        }
    }

    func deleteOldestSegment() {
        guard let oldest = segments.first else { return }

        // Delete file
        try? FileManager.default.removeItem(at: oldest.fileURL)

        // Remove from array
        segments.removeFirst()
    }

    func getCurrentBufferDuration() -> TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    func getAllSegments() -> [SegmentInfo] {
        segments
    }

    func getSegmentsForTimeRange(duration: TimeInterval) -> [SegmentInfo] {
        let totalDuration = getCurrentBufferDuration()

        // If requested duration is more than available, return all
        guard duration < totalDuration else {
            return segments
        }

        // Get segments from the end (most recent)
        var collectedDuration: TimeInterval = 0
        var selectedSegments: [SegmentInfo] = []

        for segment in segments.reversed() {
            selectedSegments.insert(segment, at: 0)
            collectedDuration += segment.duration

            if collectedDuration >= duration {
                break
            }
        }

        return selectedSegments
    }

    func clearBuffer() {
        for segment in segments {
            try? FileManager.default.removeItem(at: segment.fileURL)
        }
        segments.removeAll()
    }

    func getBufferDirectory() -> URL {
        bufferDirectory
    }
}
