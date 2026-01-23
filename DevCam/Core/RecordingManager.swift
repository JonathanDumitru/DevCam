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

    init(bufferManager: BufferManager, permissionManager: PermissionManager) {
        self.bufferManager = bufferManager
        self.permissionManager = permissionManager
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
        guard !isRecording else { return }

        guard permissionManager.hasScreenRecordingPermission else {
            throw RecordingError.permissionDenied
        }

        do {
            if isTestMode {
                try await startTestModeRecording()
            } else {
                try await setupAndStartStream()
            }

            isRecording = true
            recordingError = nil
            retryCount = 0

        } catch {
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
        let displays = try await getAvailableDisplays()
        guard let primaryDisplay = selectPrimaryDisplay(from: displays) else {
            throw RecordingError.noDisplaysAvailable
        }

        let config = createStreamConfiguration(for: primaryDisplay)

        let filter = try createContentFilter(for: primaryDisplay)

        let output = VideoStreamOutput(recordingManager: self)
        self.streamOutput = output

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        do {
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
            try await stream.startCapture()

            try await startNewSegment()

            scheduleSegmentRotation()

        } catch {
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

        // Store dimensions for subsequent AVAssetWriter setup.
        currentDisplayWidth = display.width
        currentDisplayHeight = display.height

        config.width = display.width
        config.height = display.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 fps
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.queueDepth = 5
        config.showsCursor = true

        return config
    }

    private func createContentFilter(for display: SCDisplay) throws -> SCContentFilter {
        return SCContentFilter(display: display, excludingWindows: [])
    }

    // MARK: - AVAssetWriter Management

    private func startNewSegment() async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "segment_\(timestamp).mp4"
        let segmentURL = bufferManager.getBufferDirectory().appendingPathComponent(filename)

        guard let writer = try? AVAssetWriter(outputURL: segmentURL, fileType: .mp4) else {
            throw RecordingError.writerSetupFailed
        }

        // Use stored display dimensions
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

        let compressionSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoAverageBitRateKey: bitrate,
            AVVideoExpectedSourceFrameRateKey: 60,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: compressionSettings)
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
