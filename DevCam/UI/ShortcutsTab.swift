//
//  ShortcutsTab.swift
//  DevCam
//
//  Preferences tab for customizing keyboard shortcuts
//

import SwiftUI

struct ShortcutsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shortcutManager: ShortcutManager

    @State private var editingAction: ShortcutAction?
    @State private var showingConflictAlert = false
    @State private var conflictingAction: ShortcutAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Permission warning
                if !shortcutManager.isAccessibilityEnabled {
                    accessibilityWarning
                }

                // Shortcuts list
                shortcutsList

                Divider()

                // Reset button
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        settings.resetShortcutsToDefaults()
                        shortcutManager.registerAllShortcuts()
                    }
                }
            }
            .padding()
        }
        .alert("Shortcut Conflict", isPresented: $showingConflictAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let conflict = conflictingAction {
                Text("This shortcut is already used by \"\(conflict.displayName)\". Please choose a different combination.")
            }
        }
    }

    // MARK: - Accessibility Warning

    private var accessibilityWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility Permission Required")
                    .font(.headline)
                Text("Global shortcuts require Accessibility permission to work when DevCam is in the background.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Grant Access") {
                shortcutManager.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Shortcuts List

    private var shortcutsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            ForEach(ShortcutAction.allCases) { action in
                ShortcutRow(
                    config: settings.shortcutConfig(for: action),
                    isEditing: editingAction == action,
                    onToggleEnabled: { enabled in
                        var config = settings.shortcutConfig(for: action)
                        config.isEnabled = enabled
                        settings.updateShortcut(config)
                        shortcutManager.registerAllShortcuts()
                    },
                    onStartEditing: {
                        editingAction = action
                    },
                    onKeyRecorded: { keyCode, modifiers in
                        // Check for conflicts
                        if let conflict = shortcutManager.detectConflict(
                            keyCode: keyCode,
                            modifiers: modifiers,
                            excludingAction: action
                        ) {
                            conflictingAction = conflict
                            showingConflictAlert = true
                            editingAction = nil
                            return
                        }

                        var config = settings.shortcutConfig(for: action)
                        config.keyCode = keyCode
                        config.modifiers = modifiers.rawValue
                        settings.updateShortcut(config)
                        shortcutManager.registerAllShortcuts()
                        editingAction = nil
                    },
                    onCancelEditing: {
                        editingAction = nil
                    }
                )
            }
        }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let config: ShortcutConfig
    let isEditing: Bool
    let onToggleEnabled: (Bool) -> Void
    let onStartEditing: () -> Void
    let onKeyRecorded: (UInt16, NSEvent.ModifierFlags) -> Void
    let onCancelEditing: () -> Void

    var body: some View {
        HStack {
            // Enable toggle
            Toggle("", isOn: Binding(
                get: { config.isEnabled },
                set: { onToggleEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            // Action name
            Text(config.action.displayName)
                .frame(width: 180, alignment: .leading)
                .foregroundColor(config.isEnabled ? .primary : .secondary)

            Spacer()

            // Shortcut display/recorder
            if isEditing {
                ShortcutRecorderView(
                    onKeyRecorded: onKeyRecorded,
                    onCancel: onCancelEditing
                )
            } else {
                Button(action: onStartEditing) {
                    Text(config.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!config.isEnabled)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorderView: View {
    let onKeyRecorded: (UInt16, NSEvent.ModifierFlags) -> Void
    let onCancel: () -> Void

    @State private var isListening = true
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text("Press shortcut...")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, lineWidth: 1)
                )

            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.borderless)
        }
        .onAppear {
            setupKeyCapture()
        }
        .onDisappear {
            cleanupMonitor()
        }
    }

    private func setupKeyCapture() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Require at least one modifier
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !modifiers.isEmpty else { return event }

            // Ignore escape (cancel)
            if event.keyCode == 53 {
                onCancel()
                return nil
            }

            // Ignore modifier-only presses
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modifierKeyCodes.contains(event.keyCode) else { return event }

            onKeyRecorded(event.keyCode, modifiers)
            return nil
        }
    }

    private func cleanupMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - Preview

#Preview {
    let settings = AppSettings()
    let shortcutManager = ShortcutManager(settings: settings)

    return ShortcutsTab(settings: settings, shortcutManager: shortcutManager)
        .frame(width: 480, height: 400)
}
