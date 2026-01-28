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

        do {
            try FileManager.default.removeItem(at: oldest.fileURL)
            DevCamLogger.recording.debug("Deleted oldest segment: \(oldest.fileURL.lastPathComponent)")
        } catch {
            DevCamLogger.recording.error("Failed to delete oldest segment \(oldest.fileURL.lastPathComponent): \(error.localizedDescription)")
            // Continue with buffer removal even if file deletion fails
            // The orphaned file will be cleaned up on next app launch or system cleanup
        }
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
        var deletionFailures = 0
        for segment in segments {
            do {
                try FileManager.default.removeItem(at: segment.fileURL)
            } catch {
                deletionFailures += 1
                DevCamLogger.recording.error("Failed to delete segment \(segment.fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if deletionFailures > 0 {
            DevCamLogger.recording.warning("\(deletionFailures) segment(s) could not be deleted during buffer clear")
        }
        segments.removeAll()
    }

    func getBufferDirectory() -> URL {
        bufferDirectory
    }

    // MARK: - Disk Space Monitoring

    /// Minimum required disk space for recording (500 MB)
    private let minimumRequiredSpace: Int64 = 500 * 1024 * 1024

    /// Warning threshold for low disk space (1 GB)
    private let lowSpaceWarningThreshold: Int64 = 1024 * 1024 * 1024

    /// Checks if there's sufficient disk space for recording.
    /// Returns a tuple with (hasSpace, availableSpace, isLowSpace)
    func checkDiskSpace() -> (hasSpace: Bool, availableBytes: Int64, isLowSpace: Bool) {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: bufferDirectory.path)
            guard let freeSpace = attributes[.systemFreeSize] as? Int64 else {
                DevCamLogger.recording.error("Could not determine available disk space")
                return (false, 0, true)
            }

            let hasSpace = freeSpace >= minimumRequiredSpace
            let isLowSpace = freeSpace < lowSpaceWarningThreshold

            if !hasSpace {
                DevCamLogger.recording.error("Insufficient disk space: \(freeSpace / 1024 / 1024) MB available, need \(self.minimumRequiredSpace / 1024 / 1024) MB")
            } else if isLowSpace {
                DevCamLogger.recording.warning("Low disk space warning: \(freeSpace / 1024 / 1024) MB available")
            }

            return (hasSpace, freeSpace, isLowSpace)
        } catch {
            DevCamLogger.recording.error("Failed to check disk space: \(error.localizedDescription)")
            return (false, 0, true)
        }
    }

    // MARK: - Buffer Health Checks

    /// Validates all segments in the buffer and removes any corrupted ones.
    /// Returns the number of segments that were removed due to corruption.
    @discardableResult
    func validateBuffer() -> Int {
        var removedCount = 0
        var validSegments: [SegmentInfo] = []

        for segment in segments {
            if validateSegment(segment) {
                validSegments.append(segment)
            } else {
                removedCount += 1
                DevCamLogger.recording.warning("Removing invalid segment: \(segment.fileURL.lastPathComponent)")
                do {
                    try FileManager.default.removeItem(at: segment.fileURL)
                } catch {
                    DevCamLogger.recording.error("Failed to remove invalid segment file: \(error.localizedDescription)")
                }
            }
        }

        if removedCount > 0 {
            segments = validSegments
            DevCamLogger.recording.warning("Buffer validation removed \(removedCount) invalid segment(s)")
        } else {
            DevCamLogger.recording.debug("Buffer validation complete: all \(self.segments.count) segments valid")
        }

        return removedCount
    }

    /// Validates a single segment for integrity.
    /// Checks: file exists, file size > 0, file is readable
    private func validateSegment(_ segment: SegmentInfo) -> Bool {
        let fileURL = segment.fileURL

        // Check file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            DevCamLogger.recording.error("Segment file missing: \(fileURL.lastPathComponent)")
            return false
        }

        // Check file size > 0 (detect zero-byte files)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = attributes[.size] as? UInt64, fileSize > 0 else {
                DevCamLogger.recording.error("Segment file is zero-byte: \(fileURL.lastPathComponent)")
                return false
            }
        } catch {
            DevCamLogger.recording.error("Cannot read segment file attributes: \(fileURL.lastPathComponent) - \(error.localizedDescription)")
            return false
        }

        // Check file is readable
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            DevCamLogger.recording.error("Segment file not readable: \(fileURL.lastPathComponent)")
            return false
        }

        return true
    }

    /// Returns the current segment count for monitoring.
    func getSegmentCount() -> Int {
        segments.count
    }
}
