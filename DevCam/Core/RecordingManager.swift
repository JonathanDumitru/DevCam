//
//  RecordingManager.swift
//  DevCam
//
//  Manages screen recording using ScreenCaptureKit and AVAssetWriter.
//  Coordinates continuous recording with segment-based buffer management.
//

import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit
import AVFoundation
import Combine
import OSLog
import UserNotifications

enum RecordingError: Error {
    case permissionDenied
    case noDisplaysAvailable
    case streamSetupFailed
    case writerSetupFailed
    case segmentFinalizationFailed
    case maxRetriesExceeded
    case diskSpaceLow
    case watchdogTimeout
}

@MainActor
class RecordingManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRecording: Bool = false
    @Published private(set) var bufferDuration: TimeInterval = 0
    @Published private(set) var recordingError: Error?

    // MARK: - Dependencies

    private let bufferManager: BufferManager
    private let permissionManager: PermissionManager
    private let settings: AppSettings

    // MARK: - ScreenCaptureKit

    private var stream: SCStream?
    private var streamOutput: VideoStreamOutput?
    private var currentDisplayWidth: Int = 1920
    private var currentDisplayHeight: Int = 1080

    // MARK: - AVAssetWriter

    private var currentWriter: AVAssetWriter?
    private var currentWriterInput: AVAssetWriterInput?
    private var currentAudioInput: AVAssetWriterInput?
    private var currentSegmentURL: URL?
    private var currentSegmentStartTime: Date?
    private var isWriterReady: Bool = false

    // MARK: - Audio Capture

    private var microphoneCaptureSession: AVCaptureSession?
    private var microphoneAudioOutput: AVCaptureAudioDataOutput?

    // MARK: - Timing

    private var segmentTimer: Timer?
    private let segmentDuration: TimeInterval = 60.0

    // MARK: - Error Handling

    private var retryCount: Int = 0
    private let maxRetries: Int = 3

    // MARK: - System Events

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    // MARK: - Watchdog Timer

    private var watchdogTimer: Timer?
    private var lastSegmentRotationTime: Date?
    private let watchdogInterval: TimeInterval = 90.0 // 1.5x segment duration

    // MARK: - Auto-Recovery

    private var autoRecoveryTimer: Timer?
    private let autoRecoveryCooldown: TimeInterval = 30.0 // Wait 30s before auto-restart
    private var autoRecoveryAttempts: Int = 0
    private let maxAutoRecoveryAttempts: Int = 5
    @Published private(set) var isInRecoveryMode: Bool = false

    // MARK: - Permission Monitoring

    private var permissionMonitorTimer: Timer?
    private let permissionCheckInterval: TimeInterval = 10.0 // Check every 10 seconds

    // MARK: - Periodic Buffer Validation

    private var bufferValidationTimer: Timer?
    private let bufferValidationInterval: TimeInterval = 300.0 // Validate every 5 minutes

    // MARK: - Battery Monitoring

    private var batteryMonitor: BatteryMonitor?
    private var batteryCancellable: AnyCancellable?
    @Published private(set) var isPausedForBattery: Bool = false

    // MARK: - Adaptive Quality Monitoring

    private var systemLoadMonitor: SystemLoadMonitor?
    private var systemLoadCancellable: AnyCancellable?
    private var adaptiveQualityReduced: Bool = false

    // MARK: - Quality Degradation

    private var qualityDegradationAttempted: Bool = false
    @Published private(set) var isQualityDegraded: Bool = false

    // MARK: - Test Mode

    private var isTestMode: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Logging Rate Limiting

    private var lastMetadataFrameWarning: Date = .distantPast
    private var lastDroppedFrameWarning: Date = .distantPast
    private let logWarningInterval: TimeInterval = 60.0 // Log warnings once per minute

    // MARK: - Initialization

    init(bufferManager: BufferManager, permissionManager: PermissionManager, settings: AppSettings) {
        self.bufferManager = bufferManager
        self.permissionManager = permissionManager
        self.settings = settings
        super.init()
        setupSystemEventObservers()
        startPermissionMonitoring()
        startPeriodicBufferValidation()
        setupBatteryMonitoring()
        setupAdaptiveQualityMonitoring()

        // Attempt crash recovery on initialization
        Task { @MainActor in
            await self.performCrashRecovery()
        }
    }

    deinit {
        if let sleepObserver = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
        }
        if let wakeObserver = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        // Timer invalidation must happen on MainActor
        // Since deinit is nonisolated, schedule cleanup on MainActor
        let autoRecoveryTimer = self.autoRecoveryTimer
        let permissionMonitorTimer = self.permissionMonitorTimer
        let bufferValidationTimer = self.bufferValidationTimer
        let batteryCancellable = self.batteryCancellable
        let batteryMonitor = self.batteryMonitor
        let systemLoadCancellable = self.systemLoadCancellable
        let systemLoadMonitor = self.systemLoadMonitor

        Task { @MainActor in
            autoRecoveryTimer?.invalidate()
            permissionMonitorTimer?.invalidate()
            bufferValidationTimer?.invalidate()
            batteryCancellable?.cancel()
            batteryMonitor?.stopMonitoring()
            systemLoadCancellable?.cancel()
            systemLoadMonitor?.stopMonitoring()
        }
    }

    // MARK: - Public API

    func startRecording() async throws {
        guard !isRecording else {
            DevCamLogger.recording.debug("Already recording, skipping")
            return
        }

        guard permissionManager.hasScreenRecordingPermission else {
            DevCamLogger.recording.error("Screen recording permission denied")
            throw RecordingError.permissionDenied
        }

        // Check disk space before starting
        let diskCheck = bufferManager.checkDiskSpace()
        if !diskCheck.hasSpace {
            DevCamLogger.recording.error("Cannot start recording: insufficient disk space")
            throw RecordingError.diskSpaceLow
        }

        DevCamLogger.recording.info("Starting recording")

        do {
            if isTestMode {
                try await startTestModeRecording()
            } else {
                try await setupAndStartStream()
            }

            isRecording = true
            recordingError = nil
            retryCount = 0
            qualityDegradationAttempted = false
            startWatchdog()
            DevCamLogger.recording.info("Recording started successfully at \(self.settings.effectiveRecordingQuality.displayName) quality")

        } catch {
            DevCamLogger.recording.error("Failed to start recording: \(error.localizedDescription)")
            recordingError = error
            throw error
        }
    }

    func stopRecording() async {
        guard isRecording else { return }

        segmentTimer?.invalidate()
        segmentTimer = nil
        stopWatchdog()

        await finalizeCurrentSegment()

        if let stream = stream {
            do {
                try await stream.stopCapture()
            } catch {
                DevCamLogger.recording.error("Error stopping stream: \(String(describing: error), privacy: .public)")
            }
        }

        stream = nil
        streamOutput = nil
        isRecording = false
    }

    func pauseRecording() async {
        guard isRecording else { return }

        segmentTimer?.invalidate()
        segmentTimer = nil
        stopWatchdog()

        await finalizeCurrentSegment()

        if let stream = stream {
            do {
                try await stream.stopCapture()
            } catch {
                DevCamLogger.recording.error("Error pausing stream: \(String(describing: error), privacy: .public)")
            }
        }

        isRecording = false
    }

    func resumeRecording() async throws {
        guard !isRecording else { return }
        try await startRecording()
    }

    /// Switches recording to a different display, clearing the buffer.
    /// Call this after user confirms the switch (buffer will be lost).
    ///
    /// - Parameter displayID: The display ID to switch to
    /// - Throws: RecordingError if restart fails
    func switchDisplay(to displayID: UInt32) async throws {
        DevCamLogger.recording.info("Switching to display \(displayID)")

        // Stop current recording
        await stopRecording()

        // Clear buffer - no mixed-display clips
        bufferManager.clearBuffer()
        bufferDuration = 0

        // Update settings
        settings.selectedDisplayID = displayID
        settings.displaySelectionMode = .specific

        // Restart on new display
        try await startRecording()

        DevCamLogger.recording.info("Successfully switched to display \(displayID)")
    }

    // MARK: - ScreenCaptureKit Setup

    private func setupAndStartStream() async throws {
        let displays = try await getAvailableDisplays()
        DevCamLogger.recording.debug("Found \(displays.count) display(s)")

        guard let selectedDisplay = selectDisplay(from: displays) else {
            DevCamLogger.recording.error("No display available for recording")
            throw RecordingError.noDisplaysAvailable
        }

        let config = createStreamConfiguration(for: selectedDisplay)
        DevCamLogger.recording.info("Recording display \(selectedDisplay.displayID) at \(config.width)x\(config.height)")

        let filter = try createContentFilter(for: selectedDisplay)
        let output = VideoStreamOutput(recordingManager: self)
        self.streamOutput = output

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        do {
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)

            // Add audio output if system audio capture is enabled
            if settings.audioCaptureMode.capturesSystemAudio {
                try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .main)
                DevCamLogger.recording.debug("Added audio stream output")
            }

            try await stream.startCapture()
            try await startNewSegment()
            scheduleSegmentRotation()
            DevCamLogger.recording.info("Stream capture started, segment rotation scheduled")

        } catch {
            DevCamLogger.recording.error("Stream setup failed: \(error.localizedDescription)")

            // Attempt graceful quality degradation if not already at lowest
            if let lowerQuality = settings.effectiveRecordingQuality.lowerQuality, !qualityDegradationAttempted {
                qualityDegradationAttempted = true
                DevCamLogger.recording.warning("Attempting quality degradation from \(self.settings.effectiveRecordingQuality.displayName) to \(lowerQuality.displayName)")

                settings.setDegradedQuality(lowerQuality)
                CriticalAlertManager.sendAlert(.qualityDegraded(from: settings.recordingQuality, to: lowerQuality))

                // Retry with lower quality
                try await setupAndStartStream()
                return
            }

            throw RecordingError.streamSetupFailed
        }
    }

    private func getAvailableDisplays() async throws -> [SCDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        return content.displays
    }

    /// Returns a list of available displays for UI display selection.
    /// Each entry contains the display ID and a description.
    func getDisplayList() async -> [(id: UInt32, name: String, width: Int, height: Int)] {
        do {
            let displays = try await getAvailableDisplays()
            return displays.enumerated().map { index, display in
                let name = "Display \(index + 1)"
                return (id: display.displayID, name: name, width: display.width, height: display.height)
            }
        } catch {
            DevCamLogger.recording.error("Failed to get display list: \(error.localizedDescription)")
            return []
        }
    }

    /// Selects a display based on the current display selection mode.
    private func selectDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        switch settings.displaySelectionMode {
        case .primary:
            return selectPrimaryDisplay(from: displays)

        case .specific:
            // Find display with matching ID
            if let specificDisplay = displays.first(where: { $0.displayID == settings.selectedDisplayID }) {
                return specificDisplay
            }
            // Fall back to primary if selected display not found
            DevCamLogger.recording.warning("Selected display \(self.settings.selectedDisplayID) not found, falling back to primary")
            return selectPrimaryDisplay(from: displays)

        case .all:
            // For "all displays" mode, we'd need to create a combined recording
            // This is more complex and requires compositing - fall back to primary for now
            DevCamLogger.recording.info("All displays mode not yet implemented, using primary display")
            return selectPrimaryDisplay(from: displays)
        }
    }

    private func selectPrimaryDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        return displays.max(by: { $0.width * $0.height < $1.width * $1.height })
    }

    private func createStreamConfiguration(for display: SCDisplay) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        // Apply resolution scaling based on effective quality (considers degradation)
        let effectiveQuality = settings.effectiveRecordingQuality
        let scaleFactor = effectiveQuality.scaleFactor
        isQualityDegraded = settings.isQualityDegraded
        let scaledWidth = Int(Double(display.width) * scaleFactor)
        let scaledHeight = Int(Double(display.height) * scaleFactor)

        // Store scaled dimensions for subsequent AVAssetWriter setup
        currentDisplayWidth = scaledWidth
        currentDisplayHeight = scaledHeight

        config.width = scaledWidth
        config.height = scaledHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 fps
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.queueDepth = 5
        config.showsCursor = true

        // Configure audio capture if enabled
        if settings.audioCaptureMode.capturesSystemAudio {
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            DevCamLogger.recording.debug("System audio capture enabled")
        }

        DevCamLogger.recording.debug("Stream configured: \(scaledWidth)×\(scaledHeight) at \(self.settings.recordingQuality.displayName) quality")

        return config
    }

    private func createContentFilter(for display: SCDisplay) throws -> SCContentFilter {
        return SCContentFilter(display: display, excludingWindows: [])
    }

    // MARK: - AVAssetWriter Management

    private func startNewSegment() async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "segment_\(timestamp).mp4"
        let bufferDir = bufferManager.getBufferDirectory()
        let segmentURL = bufferDir.appendingPathComponent(filename)

        guard let writer = try? AVAssetWriter(outputURL: segmentURL, fileType: .mp4) else {
            DevCamLogger.recording.error("Failed to create AVAssetWriter for \(filename)")
            throw RecordingError.writerSetupFailed
        }

        // Use stored display dimensions
        let videoInput = createVideoInput(width: currentDisplayWidth, height: currentDisplayHeight)

        guard writer.canAdd(videoInput) else {
            throw RecordingError.writerSetupFailed
        }

        writer.add(videoInput)

        // Add audio input if audio capture is enabled
        if settings.audioCaptureMode != .none {
            let audioInput = createAudioInput()
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                self.currentAudioInput = audioInput
                DevCamLogger.recording.debug("Audio input added to segment")
            } else {
                DevCamLogger.recording.warning("Could not add audio input to writer")
            }
        } else {
            self.currentAudioInput = nil
        }

        self.currentWriter = writer
        self.currentWriterInput = videoInput
        self.currentSegmentURL = segmentURL
        self.currentSegmentStartTime = Date()

        // CRITICAL FIX (2026-01-25): Prevent zero-byte segment files
        // Start writer immediately to prevent race condition where segment rotation
        // calls finishWriting() before startWriting() if only metadata frames arrive.
        //
        // Root cause: ScreenCaptureKit can send cursor/window metadata frames (no pixel buffer)
        // before actual video frames. If a 60-second segment gets only metadata frames,
        // isWriterReady stays false, and rotateSegment() calls finishWriting() on a
        // never-started writer, creating a 0-byte file.
        //
        // Solution: Start writer immediately with .zero time (will adjust on first real frame).
        // This eliminates the state machine violation and ensures all segments are valid.
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        self.isWriterReady = true
        DevCamLogger.recording.debug("Started segment: \(filename)")
    }

    private func createAudioInput() -> AVAssetWriterInput {
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]

        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        input.expectsMediaDataInRealTime = true
        return input
    }

    private func createVideoInput(width: Int, height: Int) -> AVAssetWriterInput {
        // Bitrate calculation: width × height × 0.15 bpp (bits per pixel) × 60 fps
        // 0.15 bpp provides good quality/size balance for screen recordings
        // This produces ~16 Mbps for 1920×1080 displays (1920 × 1080 × 0.15 × 60)
        let bitrate = width * height * 15 / 100 * 60

        // CRITICAL FIX: Compression properties must be nested in AVVideoCompressionPropertiesKey
        // NOT passed at the top level of outputSettings
        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoExpectedSourceFrameRateKey: 60,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]

        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compressionProperties
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = true

        return input
    }

    /// Processes video frames from ScreenCaptureKit and writes them to the current segment file.
    ///
    /// **Thread Safety**: AVAssetWriter operations must run on the thread where it was created.
    ///
    /// **Initialization**: Writer is started immediately in startNewSegment() to prevent 0-byte files.
    /// This method no longer conditionally starts the writer - it only appends frames to an already-started writer.
    ///
    /// **Fix (2026-01-25)**: Removed conditional writer start logic. Writer is now ALWAYS started
    /// upfront in startNewSegment(), eliminating the race condition that caused 0-byte segment files.
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) async {
        guard let input = currentWriterInput else {
            return
        }

        // Skip metadata frames (no pixel buffer) - writer already started in startNewSegment()
        // CRITICAL: ScreenCaptureKit occasionally sends metadata frames without pixel data
        // (cursor updates, window notifications, etc.). Skip these silently.
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else {
            // Rate-limited logging: only log once per minute to avoid spam
            let now = Date()
            if now.timeIntervalSince(lastMetadataFrameWarning) > logWarningInterval {
                DevCamLogger.recording.debug("Skipping metadata frames (no pixel buffer) - normal behavior")
                lastMetadataFrameWarning = now
            }
            return
        }

        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        } else {
            // Rate-limited logging: only log once per minute to avoid spam
            let now = Date()
            if now.timeIntervalSince(lastDroppedFrameWarning) > logWarningInterval {
                DevCamLogger.recording.warning("Dropping frames - input not ready for data")
                lastDroppedFrameWarning = now
            }
        }
    }

    /// Processes audio samples from ScreenCaptureKit (system audio) and writes them to the current segment.
    func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) async {
        guard let audioInput = currentAudioInput else {
            return
        }

        if audioInput.isReadyForMoreMediaData {
            audioInput.append(sampleBuffer)
        }
    }

    private func finalizeCurrentSegment() async {
        guard let writer = currentWriter,
              let input = currentWriterInput,
              let segmentURL = currentSegmentURL,
              let startTime = currentSegmentStartTime else {
            return
        }

        let duration = Date().timeIntervalSince(startTime)

        input.markAsFinished()

        await writer.finishWriting()

        // DIAGNOSTIC (2026-01-25): Detect zero-byte segment files
        // Added as part of Bug #2 fix to verify the race condition is resolved.
        // Before fix: ~5% of segments were 0-byte files due to AVAssetWriter state violation.
        // After fix: Should see 0 zero-byte files in logs.
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: segmentURL.path)[.size] as? UInt64 {
            if fileSize == 0 {
                DevCamLogger.recording.error("Zero-byte segment file created: \(segmentURL.lastPathComponent) - isWriterReady was: \(self.isWriterReady)")
            } else {
                DevCamLogger.recording.debug("Finalized segment: \(segmentURL.lastPathComponent) (\(fileSize) bytes)")
            }
        } else {
            DevCamLogger.recording.debug("Finalized segment: \(segmentURL.lastPathComponent)")
        }

        bufferManager.addSegment(url: segmentURL, startTime: startTime, duration: duration)

        let totalDuration = bufferManager.getCurrentBufferDuration()
        self.bufferDuration = totalDuration

        currentWriter = nil
        currentWriterInput = nil
        currentSegmentURL = nil
        currentSegmentStartTime = nil
        isWriterReady = false
    }

    // MARK: - Segment Rotation

    private func scheduleSegmentRotation() {
        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.rotateSegment()
            }
        }
    }

    private func rotateSegment() async {
        // Check disk space before creating new segment
        let diskCheck = bufferManager.checkDiskSpace()
        if !diskCheck.hasSpace {
            DevCamLogger.recording.error("Stopping recording due to insufficient disk space")
            recordingError = RecordingError.diskSpaceLow
            CriticalAlertManager.sendAlert(.diskSpaceCritical)
            await stopRecording()
            return
        } else if diskCheck.isLowSpace {
            // Warn user but continue recording
            let availableMB = Int(diskCheck.availableBytes / 1024 / 1024)
            CriticalAlertManager.sendAlert(.diskSpaceLow(availableMB: availableMB))
        }

        await finalizeCurrentSegment()

        do {
            try await startNewSegment()
            lastSegmentRotationTime = Date()
        } catch {
            DevCamLogger.recording.error("Error rotating segment: \(String(describing: error), privacy: .public)")
            recordingError = error

            retryCount += 1
            if retryCount >= maxRetries {
                CriticalAlertManager.sendAlert(.recordingStopped(reason: "Maximum retry attempts exceeded"))
                await stopRecording()
                recordingError = RecordingError.maxRetriesExceeded
                scheduleAutoRecovery()
            }
        }
    }

    // MARK: - System Event Handling

    private func setupSystemEventObservers() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pauseRecording()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                do {
                    try await self?.resumeRecording()
                    DevCamLogger.recording.info("Recording resumed after wake")
                } catch {
                    DevCamLogger.recording.error("Failed to resume recording after wake: \(error.localizedDescription)")
                    self?.recordingError = error
                }
            }
        }
    }

    // MARK: - Watchdog Timer

    /// Starts a watchdog timer to detect if segment rotation has stalled.
    /// If no segment rotation occurs within the watchdog interval, it triggers recovery.
    private func startWatchdog() {
        lastSegmentRotationTime = Date()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: watchdogInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkWatchdog()
            }
        }
        DevCamLogger.recording.debug("Watchdog timer started")
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        DevCamLogger.recording.debug("Watchdog timer stopped")
    }

    private func checkWatchdog() {
        guard isRecording else { return }

        guard let lastRotation = lastSegmentRotationTime else {
            // First segment hasn't been created yet, give it time
            return
        }

        let timeSinceRotation = Date().timeIntervalSince(lastRotation)

        // If it's been longer than watchdogInterval since last rotation, something is wrong
        if timeSinceRotation > watchdogInterval {
            DevCamLogger.recording.error("Watchdog timeout: no segment rotation in \(Int(timeSinceRotation))s, attempting recovery")

            // Attempt to recover by forcing a segment rotation
            Task { @MainActor in
                await self.attemptWatchdogRecovery()
            }
        }
    }

    private func attemptWatchdogRecovery() async {
        // First, validate buffer integrity
        bufferManager.validateBuffer()

        // Try to rotate segment
        do {
            try await startNewSegment()
            lastSegmentRotationTime = Date()
            DevCamLogger.recording.info("Watchdog recovery: segment rotation successful")
        } catch {
            DevCamLogger.recording.error("Watchdog recovery failed: \(error.localizedDescription)")

            retryCount += 1
            if retryCount >= maxRetries {
                DevCamLogger.recording.error("Watchdog: max retries exceeded, stopping recording")
                recordingError = RecordingError.watchdogTimeout
                CriticalAlertManager.sendAlert(.recordingStopped(reason: "Segment rotation timeout"))
                await stopRecording()
                scheduleAutoRecovery()
            }
        }
    }

    // MARK: - Auto-Recovery System

    /// Schedules automatic recording restart after a cooldown period.
    /// This ensures the app recovers from transient failures without user intervention.
    private func scheduleAutoRecovery() {
        guard autoRecoveryAttempts < maxAutoRecoveryAttempts else {
            DevCamLogger.recording.error("Auto-recovery: max attempts (\(self.maxAutoRecoveryAttempts)) exhausted, giving up")
            CriticalAlertManager.sendAlert(.recordingStopped(reason: "Automatic recovery failed. Please restart DevCam manually."))
            isInRecoveryMode = false
            return
        }

        // Don't schedule if already scheduled
        guard autoRecoveryTimer == nil else { return }

        isInRecoveryMode = true
        autoRecoveryAttempts += 1

        // Exponential backoff: 30s, 60s, 120s, 240s, 480s
        let backoffMultiplier = pow(2.0, Double(autoRecoveryAttempts - 1))
        let delay = autoRecoveryCooldown * backoffMultiplier

        DevCamLogger.recording.info("Auto-recovery scheduled in \(Int(delay))s (attempt \(self.autoRecoveryAttempts)/\(self.maxAutoRecoveryAttempts))")

        autoRecoveryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.attemptAutoRecovery()
            }
        }
    }

    private func attemptAutoRecovery() async {
        autoRecoveryTimer = nil

        DevCamLogger.recording.info("Auto-recovery: attempting to restart recording")

        // Check prerequisites
        guard permissionManager.hasScreenRecordingPermission else {
            DevCamLogger.recording.warning("Auto-recovery: permission denied, cannot restart")
            CriticalAlertManager.sendAlert(.permissionRevoked)
            isInRecoveryMode = false
            return
        }

        let diskCheck = bufferManager.checkDiskSpace()
        guard diskCheck.hasSpace else {
            DevCamLogger.recording.warning("Auto-recovery: insufficient disk space, will retry later")
            scheduleAutoRecovery()
            return
        }

        // Validate buffer before restarting
        bufferManager.validateBuffer()

        // Reset retry count for fresh start
        retryCount = 0

        do {
            try await startRecording()
            DevCamLogger.recording.info("Auto-recovery: recording restarted successfully")
            autoRecoveryAttempts = 0 // Reset on success
            isInRecoveryMode = false
            qualityDegradationAttempted = false // Allow degradation on next failure
            CriticalAlertManager.sendAlert(.recordingRecovered)
        } catch {
            DevCamLogger.recording.error("Auto-recovery: restart failed - \(error.localizedDescription)")
            scheduleAutoRecovery()
        }
    }

    private func stopAutoRecovery() {
        autoRecoveryTimer?.invalidate()
        autoRecoveryTimer = nil
    }

    /// Resets auto-recovery state. Call this when user manually starts recording.
    func resetAutoRecovery() {
        stopAutoRecovery()
        autoRecoveryAttempts = 0
        isInRecoveryMode = false
    }

    // MARK: - Permission Monitoring

    private func startPermissionMonitoring() {
        guard !isTestMode else { return }

        permissionMonitorTimer = Timer.scheduledTimer(withTimeInterval: permissionCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissionStatus()
            }
        }
        DevCamLogger.recording.debug("Permission monitoring started")
    }

    private func stopPermissionMonitoring() {
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
    }

    private func checkPermissionStatus() {
        let hadPermission = permissionManager.hasScreenRecordingPermission
        permissionManager.checkPermission()
        let hasPermission = permissionManager.hasScreenRecordingPermission

        // Detect permission revocation while recording
        if hadPermission && !hasPermission && isRecording {
            DevCamLogger.recording.error("Screen recording permission revoked while recording!")
            CriticalAlertManager.sendAlert(.permissionRevoked)

            Task { @MainActor in
                await self.stopRecording()
                self.recordingError = RecordingError.permissionDenied
            }
        }

        // Detect permission granted - can auto-recover if in recovery mode
        if !hadPermission && hasPermission && isInRecoveryMode {
            DevCamLogger.recording.info("Permission granted during recovery mode, attempting restart")
            Task { @MainActor in
                await self.attemptAutoRecovery()
            }
        }
    }

    // MARK: - Periodic Buffer Validation

    private func startPeriodicBufferValidation() {
        bufferValidationTimer = Timer.scheduledTimer(withTimeInterval: bufferValidationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performPeriodicValidation()
            }
        }
        DevCamLogger.recording.debug("Periodic buffer validation started (every \(Int(self.bufferValidationInterval))s)")
    }

    private func stopPeriodicBufferValidation() {
        bufferValidationTimer?.invalidate()
        bufferValidationTimer = nil
    }

    private func performPeriodicValidation() {
        let removedCount = bufferManager.validateBuffer()
        if removedCount > 0 {
            DevCamLogger.recording.warning("Periodic validation removed \(removedCount) corrupted segment(s)")
        }
    }

    // MARK: - Battery Monitoring

    private func setupBatteryMonitoring() {
        guard settings.batteryMode != .ignore else { return }

        batteryMonitor = BatteryMonitor.shared
        batteryMonitor?.startMonitoring(lowBatteryThreshold: settings.lowBatteryThreshold)

        // Observe battery state changes
        batteryCancellable = batteryMonitor?.$batteryState
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleBatteryStateChange(state)
                }
            }

        DevCamLogger.recording.debug("Battery monitoring configured: mode=\(self.settings.batteryMode.rawValue)")
    }

    private func stopBatteryMonitoring() {
        batteryCancellable?.cancel()
        batteryCancellable = nil
        batteryMonitor?.stopMonitoring()
    }

    private func handleBatteryStateChange(_ state: BatteryState) {
        guard settings.batteryMode != .ignore else { return }

        switch settings.batteryMode {
        case .ignore:
            break

        case .reduceQuality:
            handleReduceQualityOnBattery(state)

        case .pauseOnLow:
            handlePauseOnLowBattery(state)
        }
    }

    private func handleReduceQualityOnBattery(_ state: BatteryState) {
        if state.isOnBattery && !state.isCharging {
            // Reduce quality when on battery
            if !settings.isQualityDegraded {
                if let lowerQuality = settings.effectiveRecordingQuality.lowerQuality {
                    DevCamLogger.recording.info("Reducing quality due to battery power")
                    settings.setDegradedQuality(lowerQuality)
                    isQualityDegraded = true
                    CriticalAlertManager.sendAlert(.qualityDegraded(from: settings.recordingQuality, to: lowerQuality))
                }
            }
        } else if !state.isOnBattery || state.isCharging {
            // Restore quality when plugged in or charging
            if settings.isQualityDegraded {
                DevCamLogger.recording.info("Restoring quality - power connected")
                settings.resetDegradedQuality()
                isQualityDegraded = false
            }
        }
    }

    private func handlePauseOnLowBattery(_ state: BatteryState) {
        let isLowBattery = state.isOnBattery && state.batteryLevel <= settings.lowBatteryThreshold

        if isLowBattery && isRecording && !isPausedForBattery {
            // Pause recording on low battery
            DevCamLogger.recording.warning("Pausing recording due to low battery (\(state.batteryLevel)%)")
            isPausedForBattery = true

            Task { @MainActor in
                await self.pauseRecording()
                CriticalAlertManager.sendAlert(.recordingStopped(reason: "Low battery (\(state.batteryLevel)%)"))
            }

        } else if !isLowBattery && isPausedForBattery {
            // Resume recording when battery is okay or charging
            if !state.isOnBattery || state.isCharging || state.batteryLevel > settings.lowBatteryThreshold {
                DevCamLogger.recording.info("Resuming recording - battery charging or above threshold")
                isPausedForBattery = false

                Task { @MainActor in
                    do {
                        try await self.resumeRecording()
                        CriticalAlertManager.sendAlert(.recordingRecovered)
                    } catch {
                        DevCamLogger.recording.error("Failed to resume after battery: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Updates battery monitoring settings. Call when settings change.
    func updateBatteryMonitoring() {
        stopBatteryMonitoring()

        if settings.batteryMode != .ignore {
            setupBatteryMonitoring()
        }
    }

    // MARK: - Adaptive Quality Monitoring

    private func setupAdaptiveQualityMonitoring() {
        guard settings.adaptiveQualityEnabled else { return }

        systemLoadMonitor = SystemLoadMonitor.shared
        systemLoadMonitor?.startMonitoring(
            highThreshold: settings.cpuThresholdHigh,
            lowThreshold: settings.cpuThresholdLow
        )

        // Observe system load changes
        systemLoadCancellable = systemLoadMonitor?.$isHighLoad
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isHighLoad in
                Task { @MainActor [weak self] in
                    self?.handleSystemLoadChange(isHighLoad)
                }
            }

        DevCamLogger.recording.debug("Adaptive quality monitoring configured")
    }

    private func stopAdaptiveQualityMonitoring() {
        systemLoadCancellable?.cancel()
        systemLoadCancellable = nil
        systemLoadMonitor?.stopMonitoring()
    }

    private func handleSystemLoadChange(_ isHighLoad: Bool) {
        guard settings.adaptiveQualityEnabled else { return }

        if isHighLoad && !adaptiveQualityReduced {
            // Reduce quality due to high system load
            if let lowerQuality = settings.effectiveRecordingQuality.lowerQuality {
                DevCamLogger.recording.warning("Reducing quality due to high CPU load")
                settings.setDegradedQuality(lowerQuality)
                isQualityDegraded = true
                adaptiveQualityReduced = true
                CriticalAlertManager.sendAlert(.qualityDegraded(from: settings.recordingQuality, to: lowerQuality))
            }
        } else if !isHighLoad && adaptiveQualityReduced {
            // Restore quality when load normalizes
            DevCamLogger.recording.info("Restoring quality - system load normalized")
            settings.resetDegradedQuality()
            isQualityDegraded = false
            adaptiveQualityReduced = false
        }
    }

    /// Updates adaptive quality monitoring settings. Call when settings change.
    func updateAdaptiveQualityMonitoring() {
        stopAdaptiveQualityMonitoring()

        if settings.adaptiveQualityEnabled {
            setupAdaptiveQualityMonitoring()
        }
    }

    // MARK: - Crash Recovery

    /// Recovers orphaned segments from a previous crash.
    /// Scans the buffer directory for segment files not tracked in the buffer.
    private func performCrashRecovery() async {
        guard !isTestMode else { return }

        let bufferDir = bufferManager.getBufferDirectory()
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(at: bufferDir, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]) else {
            DevCamLogger.recording.debug("Crash recovery: could not read buffer directory")
            return
        }

        let segmentFiles = files.filter { $0.pathExtension == "mp4" }
        let trackedURLs = Set(bufferManager.getAllSegments().map { $0.fileURL })

        var recoveredCount = 0
        for file in segmentFiles {
            // Skip if already tracked
            if trackedURLs.contains(file) { continue }

            // Check if file is valid (non-zero size)
            guard let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                  let fileSize = attributes[.size] as? UInt64,
                  fileSize > 0 else {
                // Delete invalid orphan
                try? fileManager.removeItem(at: file)
                DevCamLogger.recording.debug("Crash recovery: deleted invalid orphan \(file.lastPathComponent)")
                continue
            }

            // Try to recover creation time from filename or file attributes
            let creationDate: Date
            if let timestamp = extractTimestamp(from: file.lastPathComponent) {
                creationDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            } else if let created = attributes[.creationDate] as? Date {
                creationDate = created
            } else {
                creationDate = Date()
            }

            // Estimate duration (assume 60s segments)
            let estimatedDuration: TimeInterval = 60.0

            // Add to buffer
            bufferManager.addSegment(url: file, startTime: creationDate, duration: estimatedDuration)
            recoveredCount += 1
            DevCamLogger.recording.info("Crash recovery: recovered segment \(file.lastPathComponent)")
        }

        if recoveredCount > 0 {
            DevCamLogger.recording.info("Crash recovery: recovered \(recoveredCount) orphaned segment(s)")

            // Validate recovered segments
            bufferManager.validateBuffer()
        }
    }

    /// Extracts Unix timestamp from segment filename (e.g., "segment_1706123456.mp4" -> 1706123456)
    private func extractTimestamp(from filename: String) -> Int? {
        let pattern = "segment_(\\d+)\\.mp4"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
              let range = Range(match.range(at: 1), in: filename) else {
            return nil
        }
        return Int(filename[range])
    }

    // MARK: - Test Mode

    private func startTestModeRecording() async throws {
        try await createTestSegment()

        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                do {
                    try await self?.createTestSegment()
                } catch {
                    DevCamLogger.recording.error("Test mode segment creation failed: \(error.localizedDescription)")
                    self?.recordingError = error
                }
            }
        }
    }

    private func createTestSegment() async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "segment_\(timestamp).mp4"
        let segmentURL = bufferManager.getBufferDirectory().appendingPathComponent(filename)
        let startTime = Date()

        // Create a placeholder file for tests.
        try "TEST_VIDEO_CONTENT".write(to: segmentURL, atomically: true, encoding: .utf8)

        bufferManager.addSegment(url: segmentURL, startTime: startTime, duration: 60.0)

        let totalDuration = bufferManager.getCurrentBufferDuration()
        self.bufferDuration = totalDuration
    }

    // MARK: - Display Disconnect Handling

    /// Checks if an error indicates the display was disconnected.
    /// ScreenCaptureKit returns specific error codes when the source display is no longer available.
    private func isDisplayDisconnectedError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // ScreenCaptureKit domain errors for display issues
        // Common codes: -3814 (display not available), -3815 (source changed)
        if nsError.domain == "com.apple.ScreenCaptureKit" {
            let displayErrors: Set<Int> = [-3814, -3815, -3816]
            return displayErrors.contains(nsError.code)
        }

        // Also check for IOSurface errors related to display disconnect
        if nsError.domain == "IOSurface" {
            return true
        }

        // Check error description for display-related keywords
        let description = error.localizedDescription.lowercased()
        return description.contains("display") && (
            description.contains("disconnect") ||
            description.contains("not available") ||
            description.contains("removed")
        )
    }

    /// Handles display disconnection by switching to primary display.
    /// Called when the currently recording display is no longer available.
    private func handleDisplayDisconnect() async {
        DevCamLogger.recording.warning("Display disconnected, switching to primary")

        // Clear buffer - can't have mixed-display clips
        bufferManager.clearBuffer()
        bufferDuration = 0

        // Switch to primary mode
        settings.displaySelectionMode = .primary

        // Restart recording on primary display
        do {
            try await startRecording()
            sendDisplayDisconnectedNotification()
            DevCamLogger.recording.info("Successfully switched to primary display after disconnect")
        } catch {
            DevCamLogger.recording.error("Failed to recover from display disconnect: \(error.localizedDescription)")
            recordingError = error
            scheduleAutoRecovery()
        }
    }

    /// Sends a notification to the user that the display was disconnected and recording has switched.
    private func sendDisplayDisconnectedNotification() {
        guard settings.showNotifications else { return }

        CriticalAlertManager.sendAlert(.recordingRecovered)

        // Also send a user-facing notification
        Task {
            let content = UNMutableNotificationContent()
            content.title = "Display Disconnected"
            content.body = "Recording switched to primary display. Buffer was cleared."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

// MARK: - SCStreamDelegate

extension RecordingManager: SCStreamDelegate {
    /// Handles stream errors from ScreenCaptureKit.
    ///
    /// **Thread Safety**: Callbacks arrive off-main; hop to @MainActor before touching state.
    ///
    /// **Retry Strategy**: Exponential backoff (1s, 2s, 4s) before giving up.
    /// **Display Disconnect**: Special handling for display disconnection errors.
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            DevCamLogger.recording.error("Stream stopped with error: \(String(describing: error), privacy: .public)")
            self.recordingError = error

            // Check for display disconnection - handle specially
            if isDisplayDisconnectedError(error) {
                DevCamLogger.recording.warning("Detected display disconnect, switching to primary")
                await handleDisplayDisconnect()
                return
            }

            if retryCount < maxRetries {
                let backoffDelay = pow(2.0, Double(retryCount)) // 1s, 2s, 4s
                try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))

                retryCount += 1
                do {
                    try await startRecording()
                    DevCamLogger.recording.info("Stream recovered after error (attempt \(self.retryCount))")
                } catch {
                    DevCamLogger.recording.error("Stream recovery failed: \(error.localizedDescription)")
                }
            } else {
                CriticalAlertManager.sendAlert(.recordingStopped(reason: "Screen capture stream error"))
                await stopRecording()
                self.recordingError = RecordingError.maxRetriesExceeded
                scheduleAutoRecovery()
            }
        }
    }
}

// MARK: - VideoStreamOutput

class VideoStreamOutput: NSObject, SCStreamOutput {
    private weak var recordingManager: RecordingManager?

    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        Task { @MainActor in
            switch type {
            case .screen:
                await recordingManager?.processSampleBuffer(sampleBuffer)
            case .audio:
                await recordingManager?.processAudioSampleBuffer(sampleBuffer)
            @unknown default:
                break
            }
        }
    }
}
