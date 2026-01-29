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

    @Published private(set) var availableWindows: [SCWindow] = []
    @Published private(set) var selectedWindows: [WindowSelection] = []
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var captureError: Error?

    // MARK: - Capture State

    private var windowStreams: [CGWindowID: SCStream] = [:]
    private var streamOutputs: [CGWindowID: WindowStreamOutput] = [:]

    // MARK: - Callbacks

    var onFrameCaptured: ((CVPixelBuffer, CGWindowID) -> Void)?

    // MARK: - Configuration

    private let settings: AppSettings

    // MARK: - Initialization

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
    }

    // MARK: - Window Discovery

    func refreshAvailableWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )

            // Filter to normal windows (exclude menubar, dock, tooltips, etc.)
            availableWindows = content.windows.filter { window in
                window.frame.width >= 100 && window.frame.height >= 100
            }

            DevCamLogger.recording.debug("Found \(self.availableWindows.count) capturable windows")
        } catch {
            DevCamLogger.recording.error("Failed to get available windows: \(error.localizedDescription)")
            availableWindows = []
        }
    }

    // MARK: - Window Selection

    func selectWindow(_ window: SCWindow, asPrimary: Bool) {
        let selection = WindowSelection(
            windowID: window.windowID,
            ownerName: window.owningApplication?.applicationName ?? "Unknown",
            windowTitle: window.title ?? "",
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

        await refreshAvailableWindows()

        for selection in selectedWindows {
            guard let window = availableWindows.first(where: { $0.windowID == selection.windowID }) else {
                DevCamLogger.recording.warning("Window \(selection.windowID) no longer available, skipping")
                continue
            }

            do {
                try await startStreamForWindow(window)
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
        isCapturing = false
    }

    // MARK: - Stream Management

    private func startStreamForWindow(_ window: SCWindow) async throws {
        let config = createStreamConfiguration(for: window)
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let output = WindowStreamOutput(windowID: window.windowID) { [weak self] buffer, windowID in
            self?.onFrameCaptured?(buffer, windowID)
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

        // Remove from selection
        let wasPrimary = selectedWindows.first { $0.windowID == windowID }?.isPrimary ?? false
        selectedWindows.removeAll { $0.windowID == windowID }

        // Promote next window to primary if needed
        if wasPrimary && !selectedWindows.isEmpty {
            selectedWindows[0].isPrimary = true
        }

        settings.updateWindowSelection(selectedWindows)

        DevCamLogger.recording.info("Window \(windowID) closed, removed from capture")
    }

    // MARK: - Warnings

    private func checkWindowCountWarning() {
        if selectedWindows.count > settings.windowCountWarningThreshold {
            DevCamLogger.recording.warning("High window count (\(self.selectedWindows.count)) may affect performance")
        }
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
