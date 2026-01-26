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

enum ExportError: Error {
    case noSegmentsAvailable
    case insufficientBufferContent
    case compositionFailed
    case exportFailed(String)
    case saveLocationUnavailable
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

    init(bufferManager: BufferManager, settings: AppSettings) {
        self.bufferManager = bufferManager
        self.settings = settings

        super.init()

        // Ensure save location directory exists
        try? FileManager.default.createDirectory(at: settings.saveLocation, withIntermediateDirectories: true)

        // Load persisted recent clips
        loadRecentClips()

        if settings.showNotifications && !isTestMode {
            requestNotificationPermission()
        }
    }

    // MARK: - Public API

    func exportClip(duration: TimeInterval) async throws {
        guard !isExporting else {
            DevCamLogger.export.notice("Export already in progress")
            return
        }

        isExporting = true
        exportProgress = 0.0
        exportError = nil

        do {
            if isTestMode {
                try await exportTestClip(duration: duration)
            } else {
                try await performExport(duration: duration)
            }
        } catch {
            exportError = error
            isExporting = false
            throw error
        }

        isExporting = false
    }

    // REMOVED: updateSaveLocation() - saveLocation now automatically reflects settings.saveLocation
    // The save location directory is ensured to exist during export operations

    func deleteClip(_ clip: ClipInfo) {
        try? FileManager.default.removeItem(at: clip.fileURL)
        recentClips.removeAll { $0.id == clip.id }
        saveRecentClips()
    }

    func clearRecentClips() {
        recentClips.removeAll()
        saveRecentClips()
    }

    // MARK: - Export Implementation

    private func performExport(duration: TimeInterval) async throws {
        // Ensure save location directory exists (handles dynamic settings changes)
        try? FileManager.default.createDirectory(at: saveLocation, withIntermediateDirectories: true)

        let segments = bufferManager.getSegmentsForTimeRange(duration: duration)

        guard !segments.isEmpty else {
            throw ExportError.noSegmentsAvailable
        }

        let availableDuration = segments.reduce(0.0) { $0 + $1.duration }

        let composition = try createComposition(from: segments)

        let outputURL = generateOutputURL()

        try await exportComposition(composition, to: outputURL)

        let fileSize = try fileSize(at: outputURL)
        let clipInfo = ClipInfo(
            id: UUID(),
            fileURL: outputURL,
            timestamp: Date(),
            duration: availableDuration,
            fileSize: fileSize
        )

        addToRecentClips(clipInfo)

        if showNotifications {
            showExportNotification(clip: clipInfo)
        }

        exportProgress = 1.0
    }

    private func createComposition(from segments: [SegmentInfo]) throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.compositionFailed
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
        try? FileManager.default.removeItem(at: outputURL)

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

    private func exportTestClip(duration: TimeInterval) async throws {
        // Ensure save location directory exists (handles dynamic settings changes)
        try? FileManager.default.createDirectory(at: saveLocation, withIntermediateDirectories: true)

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
            fileSize: fileSize
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
