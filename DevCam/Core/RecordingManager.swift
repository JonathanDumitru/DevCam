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

enum RecordingError: Error {
    case permissionDenied
    case noDisplaysAvailable
    case streamSetupFailed
    case writerSetupFailed
    case segmentFinalizationFailed
    case maxRetriesExceeded
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
    private var currentSegmentURL: URL?
    private var currentSegmentStartTime: Date?
    private var isWriterReady: Bool = false

    // MARK: - Timing

    private var segmentTimer: Timer?
    private let segmentDuration: TimeInterval = 60.0

    // MARK: - Error Handling

    private var retryCount: Int = 0
    private let maxRetries: Int = 3

    // MARK: - System Events

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    // MARK: - Test Mode

    private var isTestMode: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Initialization

    init(bufferManager: BufferManager, permissionManager: PermissionManager, settings: AppSettings) {
        self.bufferManager = bufferManager
        self.permissionManager = permissionManager
        self.settings = settings
        super.init()
        setupSystemEventObservers()
    }

    deinit {
        if let sleepObserver = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
        }
        if let wakeObserver = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    // MARK: - Public API

    func startRecording() async throws {
        print("🎥 DEBUG: RecordingManager.startRecording() CALLED")
        print("🎥 DEBUG: isRecording = \(isRecording)")

        guard !isRecording else {
            print("⚠️ DEBUG: Already recording, returning early")
            return
        }

        print("🎥 DEBUG: Checking screen recording permission")
        print("🎥 DEBUG: hasScreenRecordingPermission = \(permissionManager.hasScreenRecordingPermission)")

        guard permissionManager.hasScreenRecordingPermission else {
            print("❌ DEBUG: Permission DENIED - throwing RecordingError.permissionDenied")
            throw RecordingError.permissionDenied
        }

        print("✅ DEBUG: Permission granted, proceeding with recording setup")

        do {
            if isTestMode {
                print("🧪 DEBUG: isTestMode = true, calling startTestModeRecording()")
                try await startTestModeRecording()
            } else {
                print("🎬 DEBUG: isTestMode = false, calling setupAndStartStream()")
                try await setupAndStartStream()
                print("✅ DEBUG: setupAndStartStream() completed successfully")
            }

            isRecording = true
            recordingError = nil
            retryCount = 0
            print("✅ DEBUG: Recording started successfully! isRecording = \(isRecording)")

        } catch {
            print("❌ DEBUG: Error during recording setup: \(error)")
            recordingError = error
            throw error
        }
    }

    func stopRecording() async {
        guard isRecording else { return }

        segmentTimer?.invalidate()
        segmentTimer = nil

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

    // MARK: - ScreenCaptureKit Setup

    private func setupAndStartStream() async throws {
        print("📺 DEBUG: setupAndStartStream() - Getting available displays")
        let displays = try await getAvailableDisplays()
        print("📺 DEBUG: Found \(displays.count) displays")

        guard let primaryDisplay = selectPrimaryDisplay(from: displays) else {
            print("❌ DEBUG: No primary display found - throwing noDisplaysAvailable")
            throw RecordingError.noDisplaysAvailable
        }
        print("📺 DEBUG: Selected primary display: \(primaryDisplay.width)x\(primaryDisplay.height)")

        print("📺 DEBUG: Creating stream configuration")
        let config = createStreamConfiguration(for: primaryDisplay)
        print("📺 DEBUG: Stream config created: \(config.width)x\(config.height) @ \(config.minimumFrameInterval)")

        print("📺 DEBUG: Creating content filter")
        let filter = try createContentFilter(for: primaryDisplay)
        print("✅ DEBUG: Content filter created")

        print("📺 DEBUG: Creating VideoStreamOutput")
        let output = VideoStreamOutput(recordingManager: self)
        self.streamOutput = output
        print("✅ DEBUG: VideoStreamOutput created and stored")

        print("📺 DEBUG: Creating SCStream")
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream
        print("✅ DEBUG: SCStream created")

        do {
            print("📺 DEBUG: Adding stream output to SCStream")
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
            print("✅ DEBUG: Stream output added")

            print("📺 DEBUG: Starting stream capture (await)")
            try await stream.startCapture()
            print("✅ DEBUG: Stream capture started successfully!")

            print("📺 DEBUG: Starting new segment (await)")
            try await startNewSegment()
            print("✅ DEBUG: New segment started")

            print("📺 DEBUG: Scheduling segment rotation timer")
            scheduleSegmentRotation()
            print("✅ DEBUG: Segment rotation scheduled")

        } catch {
            print("❌ DEBUG: Error in setupAndStartStream: \(error)")
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

    private func selectPrimaryDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        return displays.max(by: { $0.width * $0.height < $1.width * $1.height })
    }

    private func createStreamConfiguration(for display: SCDisplay) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        // Apply resolution scaling based on quality setting
        print("📺 DEBUG: Current quality setting: \(settings.recordingQuality.rawValue)")
        let scaleFactor = settings.recordingQuality.scaleFactor
        print("📺 DEBUG: Scale factor: \(scaleFactor)")
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

        print("📺 DEBUG: Recording at \(scaledWidth)×\(scaledHeight) (quality: \(settings.recordingQuality.displayName), scale: \(scaleFactor))")

        return config
    }

    private func createContentFilter(for display: SCDisplay) throws -> SCContentFilter {
        return SCContentFilter(display: display, excludingWindows: [])
    }

    // MARK: - AVAssetWriter Management

    private func startNewSegment() async throws {
        print("📝 DEBUG: startNewSegment() - Creating new segment")
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "segment_\(timestamp).mp4"
        let bufferDir = bufferManager.getBufferDirectory()
        print("📝 DEBUG: Buffer directory: \(bufferDir.path)")
        let segmentURL = bufferDir.appendingPathComponent(filename)
        print("📝 DEBUG: Segment URL: \(segmentURL.path)")

        guard let writer = try? AVAssetWriter(outputURL: segmentURL, fileType: .mp4) else {
            print("❌ DEBUG: Failed to create AVAssetWriter")
            throw RecordingError.writerSetupFailed
        }
        print("✅ DEBUG: AVAssetWriter created")

        // Use stored display dimensions
        print("📝 DEBUG: Creating video input: \(currentDisplayWidth)x\(currentDisplayHeight)")
        let input = createVideoInput(width: currentDisplayWidth, height: currentDisplayHeight)

        guard writer.canAdd(input) else {
            throw RecordingError.writerSetupFailed
        }

        writer.add(input)

        self.currentWriter = writer
        self.currentWriterInput = input
        self.currentSegmentURL = segmentURL
        self.currentSegmentStartTime = Date()
        self.isWriterReady = false
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
    /// **Initialization**: Start the writer on the first frame using its presentation timestamp.
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) async {
        guard let writer = currentWriter,
              let input = currentWriterInput else {
            return
        }

        // CRITICAL: ScreenCaptureKit occasionally sends metadata frames without pixel data
        // (cursor updates, window notifications, etc.). Skip these silently.
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else {
            return
        }

        if !isWriterReady {
            writer.startWriting()
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            isWriterReady = true
        }

        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
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
        await finalizeCurrentSegment()

        do {
            try await startNewSegment()
        } catch {
            DevCamLogger.recording.error("Error rotating segment: \(String(describing: error), privacy: .public)")
            recordingError = error

            retryCount += 1
            if retryCount >= maxRetries {
                await stopRecording()
                recordingError = RecordingError.maxRetriesExceeded
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
                try? await self?.resumeRecording()
            }
        }
    }

    // MARK: - Test Mode

    private func startTestModeRecording() async throws {
        try await createTestSegment()

        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.createTestSegment()
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
}

// MARK: - SCStreamDelegate

extension RecordingManager: SCStreamDelegate {
    /// Handles stream errors from ScreenCaptureKit.
    ///
    /// **Thread Safety**: Callbacks arrive off-main; hop to @MainActor before touching state.
    ///
    /// **Retry Strategy**: Exponential backoff (1s, 2s, 4s) before giving up.
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            DevCamLogger.recording.error("Stream stopped with error: \(String(describing: error), privacy: .public)")
            self.recordingError = error

            if retryCount < maxRetries {
                let backoffDelay = pow(2.0, Double(retryCount)) // 1s, 2s, 4s
                try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))

                retryCount += 1
                try? await startRecording()
            } else {
                await stopRecording()
                self.recordingError = RecordingError.maxRetriesExceeded
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
        guard type == .screen else { return }

        Task { @MainActor in
            await recordingManager?.processSampleBuffer(sampleBuffer)
        }
    }
}
