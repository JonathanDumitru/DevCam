//
//  FrameRateController.swift
//  DevCam
//
//  Manages adaptive frame rate based on input activity and screen content.
//  Uses a state machine: Active -> PendingIdle -> Idle
//

import Foundation
import Combine
import CoreGraphics
import OSLog

/// Frame rate controller states
enum FrameRateState {
    case active
    case pendingIdle
    case idle
}

/// Controls frame rate based on user activity
@MainActor
class FrameRateController: ObservableObject {
    // MARK: - Published State

    @Published private(set) var currentFrameRate: FrameRate = .fps30
    @Published private(set) var state: FrameRateState = .active

    // MARK: - Dependencies

    private let settings: AppSettings
    private let inputMonitor: InputActivityMonitor

    // MARK: - Timers

    private var idleCheckTimer: Timer?
    private var frameComparisonTimer: Timer?
    private var idleMonitorTimer: Timer?

    // MARK: - Frame Comparison

    private var referenceFrame: CGImage?
    private let comparisonSize: Int = 32 // 32x32 downsampled
    private let changeThreshold: Double = 0.05 // 5% difference = motion

    // MARK: - Rate Limiting

    private var lastFrameRateChange: Date = .distantPast
    private let minChangeInterval: TimeInterval = 2.0

    // MARK: - Callbacks

    var onFrameRateChanged: ((FrameRate) -> Void)?

    // MARK: - Initialization

    init(settings: AppSettings, inputMonitor: InputActivityMonitor = .shared) {
        self.settings = settings
        self.inputMonitor = inputMonitor
        self.currentFrameRate = settings.targetFrameRate
    }

    // MARK: - Public API

    /// Starts the adaptive frame rate controller
    func start() {
        guard settings.adaptiveFrameRateEnabled else {
            currentFrameRate = settings.targetFrameRate
            return
        }

        inputMonitor.startMonitoring()

        // Check for idle every second
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdleState()
            }
        }

        state = .active
        currentFrameRate = settings.targetFrameRate
        DevCamLogger.recording.debug("FrameRateController: Started with target \(self.settings.targetFrameRate.rawValue) fps")
    }

    /// Stops the adaptive frame rate controller
    func stop() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil

        frameComparisonTimer?.invalidate()
        frameComparisonTimer = nil

        idleMonitorTimer?.invalidate()
        idleMonitorTimer = nil

        inputMonitor.stopMonitoring()

        state = .active
        referenceFrame = nil
        DevCamLogger.recording.debug("FrameRateController: Stopped")
    }

    /// Call when a new frame is captured (for frame comparison during transitions)
    func capturedFrame(_ image: CGImage) {
        guard state == .pendingIdle || state == .idle else { return }

        if state == .pendingIdle {
            handlePendingIdleFrame(image)
        } else if state == .idle {
            // Periodic check during idle
            if let ref = referenceFrame, !framesAreStatic(ref, image) {
                transitionToActive()
            }
        }
    }

    // MARK: - State Machine

    private func checkIdleState() {
        let idleTime = inputMonitor.timeSinceLastInput

        switch state {
        case .active:
            if idleTime >= settings.idleThreshold {
                transitionToPendingIdle()
            }

        case .pendingIdle:
            // If user becomes active, cancel transition
            if idleTime < 1.0 {
                transitionToActive()
            }

        case .idle:
            // If user becomes active, return to active immediately
            if idleTime < 1.0 {
                transitionToActive()
            }
        }
    }

    private func transitionToActive() {
        guard state != .active else { return }

        state = .active
        referenceFrame = nil

        frameComparisonTimer?.invalidate()
        frameComparisonTimer = nil

        idleMonitorTimer?.invalidate()
        idleMonitorTimer = nil

        setFrameRate(settings.targetFrameRate)
        DevCamLogger.recording.debug("FrameRateController: -> Active (\(self.settings.targetFrameRate.rawValue) fps)")
    }

    private func transitionToPendingIdle() {
        guard state == .active else { return }

        state = .pendingIdle
        referenceFrame = nil
        DevCamLogger.recording.debug("FrameRateController: -> PendingIdle (awaiting frame comparison)")

        // Wait 500ms then compare frames
        frameComparisonTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.evaluatePendingIdle()
            }
        }
    }

    private func transitionToIdle() {
        guard state == .pendingIdle else { return }

        state = .idle
        setFrameRate(settings.idleFrameRate)
        DevCamLogger.recording.debug("FrameRateController: -> Idle (\(self.settings.idleFrameRate.rawValue) fps)")

        // Periodically check if screen content changed during idle
        idleMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Frame comparison happens via capturedFrame() callback
            }
        }
    }

    private func evaluatePendingIdle() {
        // If we have a reference frame and it matches current, go idle
        // If no reference yet, we need to wait for capturedFrame() to provide frames
        if referenceFrame != nil {
            // Frame comparison already happened via capturedFrame()
            // If we're still in pendingIdle, frames matched - go idle
            if state == .pendingIdle {
                transitionToIdle()
            }
        } else {
            // No frames captured for comparison, assume static and go idle
            transitionToIdle()
        }
    }

    private func handlePendingIdleFrame(_ image: CGImage) {
        if referenceFrame == nil {
            // First frame - store as reference
            referenceFrame = image
        } else {
            // Second frame - compare
            if framesAreStatic(referenceFrame!, image) {
                // Frames match - will transition to idle via evaluatePendingIdle
            } else {
                // Frames differ - back to active
                transitionToActive()
            }
        }
    }

    // MARK: - Frame Comparison

    private func framesAreStatic(_ frame1: CGImage, _ frame2: CGImage) -> Bool {
        guard let data1 = downsampleToGrayscale(frame1),
              let data2 = downsampleToGrayscale(frame2) else {
            return true // Assume static if comparison fails
        }

        let difference = calculateDifference(data1, data2)
        return difference < changeThreshold
    }

    private func downsampleToGrayscale(_ image: CGImage) -> [UInt8]? {
        let size = comparisonSize
        let bytesPerPixel = 1
        let bytesPerRow = size * bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: size * size)

        guard let context = CGContext(
            data: &pixelData,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

        return pixelData
    }

    private func calculateDifference(_ data1: [UInt8], _ data2: [UInt8]) -> Double {
        guard data1.count == data2.count, !data1.isEmpty else { return 0 }

        var totalDiff: Int = 0
        for i in 0..<data1.count {
            totalDiff += abs(Int(data1[i]) - Int(data2[i]))
        }

        let maxDiff = data1.count * 255
        return Double(totalDiff) / Double(maxDiff)
    }

    // MARK: - Frame Rate Changes

    private func setFrameRate(_ rate: FrameRate) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameRateChange) >= minChangeInterval else {
            return
        }

        guard rate != currentFrameRate else { return }

        currentFrameRate = rate
        lastFrameRateChange = now
        onFrameRateChanged?(rate)
    }
}
