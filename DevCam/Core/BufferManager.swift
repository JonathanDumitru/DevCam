import Foundation
import OSLog

/// Manages a circular buffer of on-disk segments for rolling screen recording.
/// Keeps up to 15 one-minute segments and evicts the oldest when full.
/// Runs on the main actor to keep buffer state and UI access consistent.
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

        do {
            try FileManager.default.createDirectory(at: self.bufferDirectory, withIntermediateDirectories: true)
            DevCamLogger.recording.debug("Buffer directory created: \(self.bufferDirectory.path)")
        } catch {
            DevCamLogger.recording.error("Failed to create buffer directory: \(error.localizedDescription)")
        }
    }

    /// Adds a segment and evicts the oldest when the buffer exceeds `maxSegments`.
    func addSegment(url: URL, startTime: Date, duration: TimeInterval) {
        let segment = SegmentInfo(
            id: UUID(),
            fileURL: url,
            startTime: startTime,
            duration: duration
        )

        segments.append(segment)

        if segments.count > maxSegments {
            deleteOldestSegment()
        }
    }

    /// Removes the oldest segment and deletes its file from disk.
    func deleteOldestSegment() {
        guard let oldest = segments.first else { return }

        try? FileManager.default.removeItem(at: oldest.fileURL)
        segments.removeFirst()
    }

    func getCurrentBufferDuration() -> TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    func getAllSegments() -> [SegmentInfo] {
        segments
    }

    /// Returns the most recent segments covering `duration`, in chronological order.
    /// If `duration` exceeds the buffer, returns all segments.
    func getSegmentsForTimeRange(duration: TimeInterval) -> [SegmentInfo] {
        let totalDuration = getCurrentBufferDuration()

        guard duration < totalDuration else {
            return segments
        }

        var collectedDuration: TimeInterval = 0
        var selectedSegments: [SegmentInfo] = []

        // Iterate from newest to oldest, but preserve chronological order.
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
