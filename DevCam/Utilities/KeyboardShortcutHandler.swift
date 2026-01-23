//
//  KeyboardShortcutHandler.swift
//  DevCam
//
//  Manages global keyboard shortcuts for clip saving
//

import Foundation
import AppKit

class KeyboardShortcutHandler {
    private var eventMonitor: Any?

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

        // Remove existing monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Install local event monitor for keyboard shortcuts
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Check for Cmd+Shift modifier
            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCommandShift = modifierFlags.contains([.command, .shift])

            guard isCommandShift else { return event }

            // Check key code
            switch event.keyCode {
            case 21: // 5
                self.save5Handler?()
                return nil // Consume event
            case 22: // 6
                self.save10Handler?()
                return nil
            case 26: // 7
                self.save15Handler?()
                return nil
            default:
                return event
            }
        }
    }

    // MARK: - Cleanup

    func unregisterAll() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        save5Handler = nil
        save10Handler = nil
        save15Handler = nil
    }

    deinit {
        unregisterAll()
    }
}
