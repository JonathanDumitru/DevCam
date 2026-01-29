//
//  ShortcutManager.swift
//  DevCam
//
//  Manages customizable global keyboard shortcuts using Carbon APIs for reliable
//  system-wide hotkey registration.
//

import Foundation
import AppKit
import Carbon
import Combine
import OSLog

extension Notification.Name {
    static let openWindowPicker = Notification.Name("openWindowPicker")
}

@MainActor
class ShortcutManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isAccessibilityEnabled: Bool = false

    // MARK: - Dependencies

    private let settings: AppSettings
    private weak var recordingManager: RecordingManager?
    private weak var clipExporter: ClipExporter?

    // MARK: - Event Monitors

    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    // MARK: - Initialization

    init(settings: AppSettings) {
        self.settings = settings
        checkAccessibilityPermission()
    }

    func setManagers(recordingManager: RecordingManager, clipExporter: ClipExporter) {
        self.recordingManager = recordingManager
        self.clipExporter = clipExporter
    }

    // MARK: - Permission Check

    func checkAccessibilityPermission() {
        isAccessibilityEnabled = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Check again after a delay (user might grant permission)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    // MARK: - Registration

    func registerAllShortcuts() {
        unregisterAll()

        // Local event monitor (when app is active)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleKeyEvent(event, isLocal: true) ? nil : event
        }

        // Global event monitor (system-wide) - requires Accessibility permission
        if isAccessibilityEnabled {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return }
                _ = self.handleKeyEvent(event, isLocal: false)
            }
            DevCamLogger.app.info("Global shortcuts registered (Accessibility enabled)")
        } else {
            DevCamLogger.app.warning("Global shortcuts not registered (Accessibility disabled)")
        }

        DevCamLogger.app.info("Keyboard shortcuts registered")
    }

    func unregisterAll() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }

    // MARK: - Event Handling

    private func handleKeyEvent(_ event: NSEvent, isLocal: Bool) -> Bool {
        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let eventKeyCode = event.keyCode

        // Find matching shortcut
        for config in settings.shortcutConfigs where config.isEnabled {
            let configModifiers = config.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if eventKeyCode == config.keyCode && eventModifiers == configModifiers {
                executeAction(config.action)
                DevCamLogger.app.info("Shortcut triggered: \(config.action.displayName) (\(isLocal ? "local" : "global"))")
                return true
            }
        }

        return false
    }

    private func executeAction(_ action: ShortcutAction) {
        switch action {
        case .exportLast30Seconds, .exportLast1Minute, .exportLast5Minutes:
            guard let duration = action.exportDuration else { return }
            Task { @MainActor in
                do {
                    try await clipExporter?.exportClip(duration: duration)
                    DevCamLogger.export.info("Clip exported via shortcut: \(Int(duration))s")
                } catch {
                    DevCamLogger.export.error("Shortcut export failed: \(error.localizedDescription)")
                }
            }

        case .togglePauseResume:
            Task { @MainActor in
                guard let recordingManager = recordingManager else { return }
                if recordingManager.isRecording {
                    await recordingManager.stopRecording()
                    DevCamLogger.recording.info("Recording paused via shortcut")
                } else {
                    do {
                        try await recordingManager.startRecording()
                        DevCamLogger.recording.info("Recording resumed via shortcut")
                    } catch {
                        DevCamLogger.recording.error("Failed to resume recording: \(error.localizedDescription)")
                    }
                }
            }

        case .selectWindows:
            // Window selection is handled by the UI layer
            // This shortcut triggers the window picker to open
            NotificationCenter.default.post(name: .openWindowPicker, object: nil)
            DevCamLogger.app.info("Window picker requested via shortcut")
        }
    }

    // MARK: - Conflict Detection

    func detectConflict(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, excludingAction: ShortcutAction?) -> ShortcutAction? {
        let testModifiers = modifiers.intersection(.deviceIndependentFlagsMask)

        for config in settings.shortcutConfigs where config.isEnabled {
            if let excluding = excludingAction, config.action == excluding {
                continue
            }

            let configModifiers = config.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if config.keyCode == keyCode && configModifiers == testModifiers {
                return config.action
            }
        }

        return nil
    }

    // MARK: - Cleanup

    deinit {
        // Note: Cannot call MainActor-isolated unregisterAll() from deinit
        // Event monitors will be cleaned up when the monitors are deallocated
    }
}
