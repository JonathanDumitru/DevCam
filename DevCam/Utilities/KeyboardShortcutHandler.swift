//
//  KeyboardShortcutHandler.swift
//  DevCam
//
//  Manages global keyboard shortcuts for clip saving
//

import Foundation
import AppKit
import OSLog

class KeyboardShortcutHandler {
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    private var save5Handler: (() -> Void)?
    private var save10Handler: (() -> Void)?
    private var save15Handler: (() -> Void)?

    init() {}

    // MARK: - Registration

    func registerShortcuts(
        onSave5Minutes: @escaping () -> Void,
        onSave10Minutes: @escaping () -> Void,
        onSave15Minutes: @escaping () -> Void
    ) {
        // Store handlers
        save5Handler = onSave5Minutes
        save10Handler = onSave10Minutes
        save15Handler = onSave15Minutes

        // Remove existing monitors
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Install local event monitor (when app is active)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event, isLocal: true)
        }

        // Install global event monitor (system-wide)
        // Note: Global monitors cannot consume events, they only observe
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event, isLocal: false)
        }

        DevCamLogger.app.info("Keyboard shortcuts registered (local + global)")
    }

    // MARK: - Event Handling

    private func handleKeyEvent(_ event: NSEvent, isLocal: Bool) -> NSEvent? {
        // Check for Cmd+Shift modifier
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandShift = modifierFlags.contains([.command, .shift])

        guard isCommandShift else { return event }

        // Check key code
        let duration: TimeInterval?
        switch event.keyCode {
        case 21: // 5
            duration = 300 // 5 minutes
            save5Handler?()
        case 22: // 6
            duration = 600 // 10 minutes
            save10Handler?()
        case 26: // 7
            duration = 900 // 15 minutes
            save15Handler?()
        default:
            return event
        }

        if let duration = duration {
            let minutes = Int(duration / 60)
            DevCamLogger.app.info("Keyboard shortcut triggered: Save \(minutes) minutes (\(isLocal ? "local" : "global"))")
        }

        // Only consume event for local monitor (global monitors can't consume)
        return isLocal ? nil : event
    }

    // MARK: - Cleanup

    func unregisterAll() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        save5Handler = nil
        save10Handler = nil
        save15Handler = nil
    }

    deinit {
        unregisterAll()
    }
}
