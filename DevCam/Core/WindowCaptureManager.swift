//
//  WindowCaptureManager.swift
//  DevCam
//
//  Manages window-based screen capture using ScreenCaptureKit.
//

import Foundation
import ScreenCaptureKit
import CoreImage
import OSLog
import Combine

@MainActor
class WindowCaptureManager: NSObject, ObservableObject {

    // MARK: - Published State

    /// Stable snapshots of available windows for UI display (won't crash when accessed)
    @Published private(set) var availableWindows: [AvailableWindow] = []
    @Published private(set) var selectedWindows: [WindowSelection] = []
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var captureError: Error?

    // MARK: - Capture State

    /// Internal storage of actual SCWindow objects for capture (not exposed to UI)
    private var scWindowCache: [CGWindowID: SCWindow] = [:]
    private var windowStreams: [CGWindowID: SCStream] = [:]
    private var streamOutputs: [CGWindowID: WindowStreamOutput] = [:]

    // MARK: - Callbacks

    var onFrameCaptured: ((CVPixelBuffer, CGWindowID) -> Void)?
    var onAllWindowsClosed: (() -> Void)?

    // MARK: - Compositor

    private let compositor = WindowCompositor()
    var onCompositedFrame: ((CVPixelBuffer) -> Void)?

    // MARK: - Configuration

    private let settings: AppSettings

    // MARK: - Performance Monitoring

    private var frameCount: Int = 0
    private var lastFrameRateCheck: Date = Date()
    private let frameRateCheckInterval: TimeInterval = 10.0
    private let minimumAcceptableFpsRatio: Double = 0.5  // Warn if fps drops below 50% of target

    // MARK: - Initialization

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
    }

    // MARK: - Window Discovery

    /// Clears available windows before overlay dismissal to prevent crashes during view teardown.
    func clearAvailableWindows() {
        availableWindows = []
    }

    /// Refreshes the list of available windows for UI display using CGWindowList API.
    /// This avoids ScreenCaptureKit entirely for UI display to prevent crashes from dangling SCWindow references.
    func refreshAvailableWindows() async {
        // Use CGWindowListCopyWindowInfo instead of ScreenCaptureKit for UI display
        // This is more stable and doesn't have the dangling pointer issue
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            DevCamLogger.recording.error("Failed to get window list from CGWindowListCopyWindowInfo")
            availableWindows = []
            return
        }

        var windows: [AvailableWindow] = []

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }

            // Filter out small windows (menubar, tooltips, etc.)
            guard width >= 100 && height >= 100 else { continue }

            // Filter out windows without a valid layer (typically system UI)
            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }  // Normal windows are at layer 0

            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""

            let frame = CGRect(x: x, y: y, width: width, height: height)

            windows.append(AvailableWindow(
                windowID: windowID,
                ownerName: ownerName,
                windowTitle: windowTitle,
                frame: frame
            ))
        }

        availableWindows = windows
        DevCamLogger.recording.debug("Found \(self.availableWindows.count) capturable windows via CGWindowList")
    }

    /// Fetches fresh SCWindow objects for capture. Called right before starting capture.
    private func refreshWindowCache() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )

            scWindowCache.removeAll()
            for window in content.windows {
                scWindowCache[window.windowID] = window
            }
        } catch {
            DevCamLogger.recording.error("Failed to refresh window cache: \(error.localizedDescription)")
            scWindowCache.removeAll()
        }
    }

    // MARK: - Window Selection

    func selectWindow(_ window: AvailableWindow, asPrimary: Bool) {
        let selection = WindowSelection(
            windowID: window.windowID,
            ownerName: window.ownerName,
            windowTitle: window.windowTitle,
            isPrimary: asPrimary
        )

        // If setting as primary, demote existing primary
        if asPrimary {
            selectedWindows = selectedWindows.map { existing in
                var updated = existing
                updated.isPrimary = false
                return updated
            }
        }

        // Add or update selection
        if let index = selectedWindows.firstIndex(where: { $0.windowID == window.windowID }) {
            selectedWindows[index] = selection
        } else {
            selectedWindows.append(selection)
        }

        // If this is the first window, make it primary
        if selectedWindows.count == 1 {
            selectedWindows[0].isPrimary = true
        }

        settings.updateWindowSelection(selectedWindows)
        checkWindowCountWarning()
    }

    func deselectWindow(_ windowID: CGWindowID) {
        selectedWindows.removeAll { $0.windowID == windowID }

        // If we removed the primary, promote the first remaining window
        if !selectedWindows.isEmpty && !selectedWindows.contains(where: { $0.isPrimary }) {
            selectedWindows[0].isPrimary = true
        }

        settings.updateWindowSelection(selectedWindows)
    }

    func setPrimaryWindow(_ windowID: CGWindowID) {
        selectedWindows = selectedWindows.map { selection in
            var updated = selection
            updated.isPrimary = (selection.windowID == windowID)
            return updated
        }
        settings.updateWindowSelection(selectedWindows)
    }

    func clearSelection() {
        selectedWindows = []
        settings.clearWindowSelection()
    }

    // MARK: - Capture Control

    func startCapture() async throws {
        guard !selectedWindows.isEmpty else {
            DevCamLogger.recording.warning("No windows selected for capture")
            return
        }

        resetPerformanceCounters()
        // Fetch fresh SCWindow objects right before capture
        await refreshWindowCache()

        for selection in selectedWindows {
            guard let scWindow = scWindowCache[selection.windowID] else {
                DevCamLogger.recording.warning("Window \(selection.windowID) no longer available, skipping")
                continue
            }

            do {
                try await startStreamForWindow(scWindow)
            } catch {
                DevCamLogger.recording.error("Failed to start capture for window \(selection.windowID): \(error.localizedDescription)")
            }
        }

        isCapturing = !windowStreams.isEmpty
    }

    func stopCapture() async {
        for (windowID, stream) in windowStreams {
            do {
                try await stream.stopCapture()
                DevCamLogger.recording.debug("Stopped capture for window \(windowID)")
            } catch {
                DevCamLogger.recording.error("Error stopping stream for window \(windowID): \(error.localizedDescription)")
            }
        }

        windowStreams.removeAll()
        streamOutputs.removeAll()
        compositor.clearAllFrames()
        resetPerformanceCounters()
        isCapturing = false
    }

    // MARK: - Stream Management

    private func startStreamForWindow(_ window: SCWindow) async throws {
        let config = createStreamConfiguration(for: window)
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let output = WindowStreamOutput(windowID: window.windowID) { [weak self] buffer, windowID in
            self?.handleCapturedFrame(buffer, from: windowID)
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
        try await stream.startCapture()

        windowStreams[window.windowID] = stream
        streamOutputs[window.windowID] = output

        DevCamLogger.recording.info("Started capture for window: \(window.title ?? "Untitled") (\(window.windowID))")
    }

    private func createStreamConfiguration(for window: SCWindow) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        let scaleFactor = settings.effectiveRecordingQuality.scaleFactor
        config.width = Int(Double(window.frame.width) * scaleFactor)
        config.height = Int(Double(window.frame.height) * scaleFactor)
        config.minimumFrameInterval = settings.targetFrameRate.frameInterval
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.queueDepth = 5
        config.showsCursor = true

        return config
    }

    private func handleCapturedFrame(_ buffer: CVPixelBuffer, from windowID: CGWindowID) {
        trackFrameForPerformance()
        compositor.updateFrame(buffer, for: windowID)

        // Composite and emit
        let primaryID = primaryWindow?.windowID
        let secondaryIDs = secondaryWindows.map { $0.windowID }

        if let composited = compositor.compositeFrames(
            primaryWindowID: primaryID,
            secondaryWindowIDs: secondaryIDs
        ) {
            onCompositedFrame?(composited)
        }
    }

    // MARK: - Window Lifecycle

    func handleWindowClosed(_ windowID: CGWindowID) async {
        // Stop stream for this window
        if let stream = windowStreams[windowID] {
            do {
                try await stream.stopCapture()
            } catch {
                DevCamLogger.recording.error("Error stopping stream for closed window: \(error.localizedDescription)")
            }
            windowStreams.removeValue(forKey: windowID)
            streamOutputs.removeValue(forKey: windowID)
        }

        compositor.clearFrame(for: windowID)

        // Remove from selection
        let wasPrimary = selectedWindows.first { $0.windowID == windowID }?.isPrimary ?? false
        selectedWindows.removeAll { $0.windowID == windowID }

        // Promote next window to primary if needed
        if wasPrimary && !selectedWindows.isEmpty {
            selectedWindows[0].isPrimary = true
        }

        settings.updateWindowSelection(selectedWindows)

        DevCamLogger.recording.info("Window \(windowID) closed, removed from capture")

        // Trigger fallback callback when all windows are closed
        if selectedWindows.isEmpty {
            DevCamLogger.recording.info("All windows closed, triggering fallback")
            onAllWindowsClosed?()
        }
    }

    // MARK: - Warnings

    private func checkWindowCountWarning() {
        if selectedWindows.count > settings.windowCountWarningThreshold {
            DevCamLogger.recording.warning("High window count (\(self.selectedWindows.count)) may affect performance")
        }
    }

    // MARK: - Performance Tracking

    private func trackFrameForPerformance() {
        frameCount += 1
        checkFrameRate()
    }

    private func checkFrameRate() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFrameRateCheck)

        guard elapsed >= frameRateCheckInterval else { return }

        let fps = Double(frameCount) / elapsed
        let targetFps = Double(settings.targetFrameRate.rawValue)

        if fps < targetFps * minimumAcceptableFpsRatio {
            DevCamLogger.recording.warning("Window capture frame rate degraded: \(Int(fps)) fps (target: \(Int(targetFps)))")
            // Could add a notification or callback here for UI feedback
        } else {
            DevCamLogger.recording.debug("Window capture frame rate: \(Int(fps)) fps")
        }

        // Reset counters
        frameCount = 0
        lastFrameRateCheck = now
    }

    private func resetPerformanceCounters() {
        frameCount = 0
        lastFrameRateCheck = Date()
    }

    // MARK: - Helpers

    var primaryWindow: WindowSelection? {
        selectedWindows.first { $0.isPrimary }
    }

    var secondaryWindows: [WindowSelection] {
        selectedWindows.filter { !$0.isPrimary }
    }

    var windowCount: Int {
        selectedWindows.count
    }

    func setOutputSize(_ size: CGSize) {
        compositor.outputSize = size
    }
}

// MARK: - Window Stream Output

private class WindowStreamOutput: NSObject, SCStreamOutput {
    let windowID: CGWindowID
    let onFrame: (CVPixelBuffer, CGWindowID) -> Void

    init(windowID: CGWindowID, onFrame: @escaping (CVPixelBuffer, CGWindowID) -> Void) {
        self.windowID = windowID
        self.onFrame = onFrame
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        onFrame(pixelBuffer, windowID)
    }
}
