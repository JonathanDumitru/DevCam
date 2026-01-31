//
//  InputActivityMonitor.swift
//  DevCam
//
//  Monitors mouse and keyboard activity to detect idle periods.
//  Used by FrameRateController for adaptive frame rate.
//

import Foundation
import AppKit
import Combine
import OSLog

/// Monitors system-wide input activity (mouse/keyboard)
@MainActor
class InputActivityMonitor: ObservableObject {
    static let shared = InputActivityMonitor()

    @Published private(set) var lastInputTime: Date = Date()
    @Published private(set) var isMonitoring: Bool = false

    private var mouseMonitor: Any?
    private var keyboardMonitor: Any?

    var timeSinceLastInput: TimeInterval {
        Date().timeIntervalSince(lastInputTime)
    }

    private init() {}

    /// Starts monitoring input events. Requires Accessibility permission.
    func startMonitoring() {
        guard !isMonitoring else { return }

        // Check accessibility permission
        let trusted = AXIsProcessTrusted()
        if !trusted {
            DevCamLogger.recording.warning("InputActivityMonitor: Accessibility permission not granted")
            // Don't start monitoring without permission
            return
        }

        // Monitor mouse events
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordInput()
            }
        }

        // Monitor keyboard events
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordInput()
            }
        }

        isMonitoring = true
        lastInputTime = Date()
        DevCamLogger.recording.debug("InputActivityMonitor: Started monitoring")
    }

    /// Stops monitoring input events
    func stopMonitoring() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }

        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }

        isMonitoring = false
        DevCamLogger.recording.debug("InputActivityMonitor: Stopped monitoring")
    }

    private func recordInput() {
        lastInputTime = Date()
    }

    /// Checks if Accessibility permission is granted
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts user for Accessibility permission
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
