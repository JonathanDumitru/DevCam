//
//  ClipExporter.swift
//  DevCam
//
//  Handles extraction and export of video clips from the circular buffer.
//  Uses AVAssetExportSession to stitch segments together.
//

import Foundation
import Combine
import AVFoundation
import UserNotifications
import OSLog

enum ExportError: Error, Equatable {
    case noSegmentsAvailable
    case insufficientBufferContent
    case compositionFailed
    case exportFailed(String)
    case saveLocationUnavailable
    case diskSpaceLow
    case maxRetriesExceeded

    var isRetryable: Bool {
        switch self {
        case .exportFailed, .compositionFailed:
            return true
        case .noSegmentsAvailable, .insufficientBufferContent, .saveLocationUnavailable, .diskSpaceLow, .maxRetriesExceeded:
            return false
        }
    }
}

@MainActor
class ClipExporter: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var exportProgress: Double = 0.0
    @Published private(set) var isExporting: Bool = false
    @Published private(set) var recentClips: [ClipInfo] = []
    @Published private(set) var exportError: Error?

    // MARK: - Dependencies

    private let bufferManager: BufferManager
    private let settings: AppSettings

    // MARK: - Configuration

    private var saveLocation: URL {
        settings.saveLocation
    }

    private var showNotifications: Bool {
        settings.showNotifications
    }
    private let maxRecentClips: Int = 20
    private let recentClipsKey = "recentClips"

    // MARK: - Export Queue

    // Export queue is for potential background work; current implementation
    // uses @MainActor for simplicity. Could move heavy processing here in future
    // (e.g., parallel segment validation, thumbnail generation, metadata extraction).
    private let exportQueue = DispatchQueue(label: "com.devcam.export", qos: .userInitiated)
    private var currentExportSession: AVAssetExportSession?

    // MARK: - Test Mode

    private var isTestMode: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Initialization

    // MARK: - Retry Configuration

    private let maxExportRetries: Int = 3
    private var currentRetryCount: Int = 0

    init(bufferManager: BufferManager, settings: AppSettings) {
        self.bufferManager = bufferManager
        self.settings = settings

        super.init()

        // Ensure save location directory exists
        do {
            try FileManager.default.createDirectory(at: settings.saveLocation, withIntermediateDirectories: true)
            DevCamLogger.export.debug("Save location directory ensured: \(settings.saveLocation.path)")
        } catch {
            DevCamLogger.export.error("Failed to create save location directory: \(error.localizedDescription)")
        }

        // Load persisted recent clips
        loadRecentClips()

        if settings.showNotifications && !isTestMode {
            requestNotificationPermission()
        }
    }

    // MARK: - Public API

    /// Export a clip with optional annotations.
    /// - Parameters:
    ///   - duration: Duration of the clip in seconds
    ///   - title: Optional title for the clip
    ///   - notes: Optional notes/description
    ///   - tags: Optional array of tags
    func exportClip(
        duration: TimeInterval,
        title: String? = nil,
        notes: String? = nil,
        tags: [String] = []
    ) async throws {
        guard !isExporting else {
            DevCamLogger.export.notice("Export already in progress")
            return
        }

        isExporting = true
        exportProgress = 0.0
        exportError = nil

        do {
            if isTestMode {
                try await exportTestClip(duration: duration, title: title, notes: notes, tags: tags)
            } else {
                try await performExport(duration: duration, title: title, notes: notes, tags: tags)
            }
        } catch {
            exportError = error
            isExporting = false

            // Send critical alert for export failures (only for non-trivial errors)
            if let exportError = error as? ExportError {
                switch exportError {
                case .maxRetriesExceeded:
                    CriticalAlertManager.sendAlert(.exportFailed(reason: "Export failed after multiple attempts"))
                case .diskSpaceLow:
                    CriticalAlertManager.sendAlert(.exportFailed(reason: "Insufficient disk space"))
                case .saveLocationUnavailable:
                    CriticalAlertManager.sendAlert(.exportFailed(reason: "Save location not accessible"))
                case .noSegmentsAvailable:
                    // Don't alert for this - it's expected if buffer is empty
                    break
                default:
                    CriticalAlertManager.sendAlert(.exportFailed(reason: "Unexpected error"))
                }
            }

            throw error
        }

        isExporting = false
    }

    // REMOVED: updateSaveLocation() - saveLocation now automatically reflects settings.saveLocation
    // The save location directory is ensured to exist during export operations

    /// Prepare a temporary video file for preview playback.
    /// - Parameter duration: Duration of content to include in preview
    /// - Returns: URL to the temporary preview file, or nil if insufficient buffer
    func preparePreview(duration: TimeInterval) async throws -> URL? {
        guard !isExporting else {
            DevCamLogger.export.notice("Export already in progress, cannot prepare preview")
            return nil
        }

        let segments = bufferManager.getSegmentsForTimeRange(duration: duration)

        guard !segments.isEmpty else {
            DevCamLogger.export.notice("No segments available for preview")
            return nil
        }

        DevCamLogger.export.debug("Preparing preview with \(segments.count) segments")

        let composition = try createComposition(from: segments)

        // Generate temp file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let tempURL = tempDirectory.appendingPathComponent("DevCam_Preview_\(timestamp).mp4")

        try await exportComposition(composition, to: tempURL)

        DevCamLogger.export.debug("Preview prepared at: \(tempURL.path)")
        return tempURL
    }

    /// Export a trimmed clip with a specific time range.
    /// - Parameters:
    ///   - timeRange: The CMTimeRange to export
    ///   - sourceURL: URL of the source video (usually the preview temp file)
    func exportClipWithRange(_ timeRange: CMTimeRange, from sourceURL: URL) async throws {
        guard !isExporting else {
            DevCamLogger.export.notice("Export already in progress")
            return
        }

        isExporting = true
        exportProgress = 0.0
        exportError = nil

        do {
            // Ensure save location directory exists
            try FileManager.default.createDirectory(at: saveLocation, withIntermediateDirectories: true)

            let sourceAsset = AVURLAsset(url: sourceURL)
            let composition = AVMutableComposition()

            guard let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw ExportError.compositionFailed
            }

            // Check if source has audio
            let hasAudio = !sourceAsset.tracks(withMediaType: .audio).isEmpty
            let audioTrack: AVMutableCompositionTrack? = hasAudio
                ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                : nil

            guard let sourceVideoTrack = sourceAsset.tracks(withMediaType: .video).first else {
                throw ExportError.compositionFailed
            }

            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)

            if let audioTrack = audioTrack,
               let sourceAudioTrack = sourceAsset.tracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
            }

            let outputURL = generateOutputURL()
            try await exportComposition(composition, to: outputURL)

            let clipDuration = CMTimeGetSeconds(timeRange.duration)
            let fileSize = try self.fileSize(at: outputURL)

            let clipInfo = ClipInfo(
                id: UUID(),
                fileURL: outputURL,
                timestamp: Date(),
                duration: clipDuration,
                fileSize: fileSize,
                title: nil,
                notes: nil,
                tags: []
            )

            addToRecentClips(clipInfo)

            if showNotifications {
                showExportNotification(clip: clipInfo)
            }

            exportProgress = 1.0
            DevCamLogger.export.debug("Trimmed clip exported: \(outputURL.lastPathComponent)")

        } catch {
            exportError = error
            isExporting = false
            DevCamLogger.export.error("Failed to export trimmed clip: \(error.localizedDescription)")
            throw error
        }

        isExporting = false
    }

    func deleteClip(_ clip: ClipInfo) {
        do {
            try FileManager.default.removeItem(at: clip.fileURL)
            DevCamLogger.export.debug("Deleted clip: \(clip.fileURL.lastPathComponent)")
        } catch {
            DevCamLogger.export.error("Failed to delete clip \(clip.fileURL.lastPathComponent): \(error.localizedDescription)")
            // Continue with removing from recent clips list even if file deletion fails
        }
        recentClips.removeAll { $0.id == clip.id }
        saveRecentClips()
    }

    func clearRecentClips() {
        recentClips.removeAll()
        saveRecentClips()
    }

    // MARK: - Export Implementation

    private func performExport(
        duration: TimeInterval,
        title: String? = nil,
        notes: String? = nil,
        tags: [String] = []
    ) async throws {
        // Check disk space before export
        let diskCheck = bufferManager.checkDiskSpace()
        if !diskCheck.hasSpace {
            DevCamLogger.export.error("Cannot export: insufficient disk space")
            throw ExportError.diskSpaceLow
        }

        // Ensure save location directory exists (handles dynamic settings changes)
        do {
            try FileManager.default.createDirectory(at: saveLocation, withIntermediateDirectories: true)
        } catch {
            DevCamLogger.export.error("Failed to create save location: \(error.localizedDescription)")
            throw ExportError.saveLocationUnavailable
        }

        // Validate buffer before export
        bufferManager.validateBuffer()

        let segments = bufferManager.getSegmentsForTimeRange(duration: duration)

        guard !segments.isEmpty else {
            throw ExportError.noSegmentsAvailable
        }

        let availableDuration = segments.reduce(0.0) { $0 + $1.duration }

        // Retry loop for transient failures
        var lastError: Error?
        currentRetryCount = 0

        while currentRetryCount < maxExportRetries {
            do {
                let composition = try createComposition(from: segments)
                let outputURL = generateOutputURL()

                try await exportComposition(composition, to: outputURL)

                let fileSize = try fileSize(at: outputURL)
                let clipInfo = ClipInfo(
                    id: UUID(),
                    fileURL: outputURL,
                    timestamp: Date(),
                    duration: availableDuration,
                    fileSize: fileSize,
                    title: title,
                    notes: notes,
                    tags: tags
                )

                addToRecentClips(clipInfo)

                if showNotifications {
                    showExportNotification(clip: clipInfo)
                }

                exportProgress = 1.0
                currentRetryCount = 0 // Reset on success
                return

            } catch let error as ExportError where error.isRetryable {
                currentRetryCount += 1
                lastError = error
                DevCamLogger.export.warning("Export attempt \(self.currentRetryCount) failed: \(error.localizedDescription). Retrying...")

                if currentRetryCount < maxExportRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let backoffDelay = pow(2.0, Double(currentRetryCount - 1))
                    try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }

            } catch {
                // Non-retryable error, fail immediately
                DevCamLogger.export.error("Export failed with non-retryable error: \(error.localizedDescription)")
                throw error
            }
        }

        // All retries exhausted
        DevCamLogger.export.error("Export failed after \(self.maxExportRetries) attempts")
        throw ExportError.maxRetriesExceeded
    }

    private func createComposition(from segments: [SegmentInfo]) throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.compositionFailed
        }

        // Check if first segment has audio - if so, create an audio track for stitching
        let firstAsset = AVURLAsset(url: segments.first!.fileURL)
        let hasAudio = !firstAsset.tracks(withMediaType: .audio).isEmpty

        let audioTrack: AVMutableCompositionTrack? = hasAudio
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil

        if hasAudio {
            DevCamLogger.export.debug("Audio track detected, will stitch audio with video")
        }

        var currentTime = CMTime.zero

        for segment in segments {
            let asset = AVURLAsset(url: segment.fileURL)

            guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
                DevCamLogger.export.notice(
                    "Segment \(segment.fileURL.lastPathComponent, privacy: .public) has no video track; skipping"
                )
                continue
            }

            let timeRange = CMTimeRange(start: .zero, duration: asset.duration)

            do {
                try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)

                // Insert audio track if available (gracefully skip segments without audio)
                if let audioTrack = audioTrack,
                   let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
                    try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                }

                currentTime = CMTimeAdd(currentTime, asset.duration)
            } catch {
                DevCamLogger.export.notice(
                    "Failed to insert segment \(segment.fileURL.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                // Skip failed segments so the export can still complete.
            }
        }

        return composition
    }

    private func exportComposition(_ composition: AVMutableComposition, to outputURL: URL) async throws {
        // Remove existing file if present (shouldn't happen with unique timestamps, but be safe)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
                DevCamLogger.export.debug("Removed existing file at export URL")
            } catch {
                DevCamLogger.export.error("Failed to remove existing file at export URL: \(error.localizedDescription)")
                throw ExportError.exportFailed("Cannot overwrite existing file: \(error.localizedDescription)")
            }
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.exportFailed("Failed to create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        self.currentExportSession = exportSession

        // Poll progress for UI updates; exportSession.progress is thread-safe.
        let progressTask = Task { @MainActor in
            while exportSession.status == .exporting || exportSession.status == .waiting {
                self.exportProgress = Double(exportSession.progress)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }

        await exportSession.export()

        progressTask.cancel()

        switch exportSession.status {
        case .completed:
            self.exportProgress = 1.0
        case .failed:
            if let error = exportSession.error {
                throw ExportError.exportFailed(error.localizedDescription)
            } else {
                throw ExportError.exportFailed("Unknown export error")
            }
        case .cancelled:
            throw ExportError.exportFailed("Export cancelled")
        default:
            throw ExportError.exportFailed("Unexpected export status: \(exportSession.status.rawValue)")
        }

        self.currentExportSession = nil
    }

    private func generateOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "DevCam_\(timestamp).mp4"
        return saveLocation.appendingPathComponent(filename)
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    private func addToRecentClips(_ clip: ClipInfo) {
        recentClips.insert(clip, at: 0)

        if recentClips.count > maxRecentClips {
            recentClips = Array(recentClips.prefix(maxRecentClips))
        }

        saveRecentClips()
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                DevCamLogger.export.error(
                    "Notification permission error: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private func showExportNotification(clip: ClipInfo) {
        let content = UNMutableNotificationContent()
        content.title = "Clip Saved"
        content.body = "Saved \(clip.durationFormatted) clip (\(clip.fileSizeFormatted))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: clip.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DevCamLogger.export.error(
                    "Failed to show notification: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    // MARK: - Test Mode

    private func exportTestClip(
        duration: TimeInterval,
        title: String? = nil,
        notes: String? = nil,
        tags: [String] = []
    ) async throws {
        // Ensure save location directory exists (handles dynamic settings changes)
        do {
            try FileManager.default.createDirectory(at: saveLocation, withIntermediateDirectories: true)
        } catch {
            DevCamLogger.export.error("Failed to create test save location: \(error.localizedDescription)")
            throw ExportError.saveLocationUnavailable
        }

        let segments = bufferManager.getSegmentsForTimeRange(duration: duration)

        guard !segments.isEmpty else {
            throw ExportError.noSegmentsAvailable
        }

        let availableDuration = segments.reduce(0.0) { $0 + $1.duration }

        let outputURL = generateOutputURL()
        let testContent = "TEST_CLIP_CONTENT_\(duration)s"
        try testContent.write(to: outputURL, atomically: true, encoding: .utf8)

        for progress in stride(from: 0.0, through: 1.0, by: 0.2) {
            exportProgress = progress
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        }

        let fileSize = Int64(testContent.count)
        let clipInfo = ClipInfo(
            id: UUID(),
            fileURL: outputURL,
            timestamp: Date(),
            duration: availableDuration,
            fileSize: fileSize,
            title: title,
            notes: notes,
            tags: tags
        )

        addToRecentClips(clipInfo)

        exportProgress = 1.0
    }

    // MARK: - Persistence

    private func loadRecentClips() {
        guard let data = UserDefaults.standard.data(forKey: recentClipsKey),
              let clips = try? JSONDecoder().decode([ClipInfo].self, from: data) else {
            return
        }

        // Filter out clips whose files no longer exist
        recentClips = clips.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }

        // Save filtered list if any clips were removed
        if recentClips.count != clips.count {
            saveRecentClips()
        }
    }

    private func saveRecentClips() {
        guard let data = try? JSONEncoder().encode(recentClips) else {
            return
        }
        UserDefaults.standard.set(data, forKey: recentClipsKey)
    }

    // MARK: - Cancellation

    func cancelExport() {
        currentExportSession?.cancelExport()
        currentExportSession = nil
        isExporting = false
        exportProgress = 0.0
    }
}
