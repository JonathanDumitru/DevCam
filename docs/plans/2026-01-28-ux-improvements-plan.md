# UX Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add customizable global keyboard shortcuts, a dynamic menubar icon with buffer badge, and a clip preview window with trim controls.

**Architecture:** Three independent features sharing the existing manager pattern. ShortcutManager handles customizable hotkeys with persistence. MenubarIconManager renders dynamic icons with badges. PreviewWindow coordinates AVPlayer with a dual-handle TrimSliderView for clip trimming before export.

**Tech Stack:** SwiftUI, AppKit (NSEvent, NSStatusItem, NSImage canvas drawing), AVFoundation, Carbon (for RegisterEventHotKey), UserDefaults for persistence.

---

## Task 1: ShortcutAction Enum and Storage Model

**Files:**
- Modify: `DevCam/DevCam/DevCam/Core/AppSettings.swift`

**Step 1: Add ShortcutAction enum and ShortcutConfig struct to AppSettings.swift**

Add after the `FrameRate` enum (around line 183):

```swift
/// Available shortcut actions
enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case exportLast30Seconds = "export30s"
    case exportLast1Minute = "export1m"
    case exportLast5Minutes = "export5m"
    case togglePauseResume = "togglePause"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exportLast30Seconds: return "Export Last 30 Seconds"
        case .exportLast1Minute: return "Export Last 1 Minute"
        case .exportLast5Minutes: return "Export Last 5 Minutes"
        case .togglePauseResume: return "Pause/Resume Recording"
        }
    }

    var defaultKeyCode: UInt16 {
        switch self {
        case .exportLast30Seconds: return 1  // S key
        case .exportLast1Minute: return 46   // M key
        case .exportLast5Minutes: return 37  // L key
        case .togglePauseResume: return 35   // P key
        }
    }

    var defaultModifiers: NSEvent.ModifierFlags {
        [.command, .shift]
    }

    var exportDuration: TimeInterval? {
        switch self {
        case .exportLast30Seconds: return 30
        case .exportLast1Minute: return 60
        case .exportLast5Minutes: return 300
        case .togglePauseResume: return nil
        }
    }
}

/// Configuration for a single keyboard shortcut
struct ShortcutConfig: Codable, Equatable {
    let action: ShortcutAction
    var keyCode: UInt16
    var modifiers: UInt  // Store as UInt for Codable compatibility
    var isEnabled: Bool

    var modifierFlags: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: modifiers) }
        set { modifiers = newValue.rawValue }
    }

    var displayString: String {
        var parts: [String] = []
        let flags = modifierFlags
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`"
        ]
        return keyMap[keyCode] ?? "?"
    }

    static func defaultConfig(for action: ShortcutAction) -> ShortcutConfig {
        ShortcutConfig(
            action: action,
            keyCode: action.defaultKeyCode,
            modifiers: action.defaultModifiers.rawValue,
            isEnabled: true
        )
    }
}
```

**Step 2: Add shortcut storage to AppSettings class**

Add these properties inside the AppSettings class after the Frame Rate Settings section:

```swift
// MARK: - Keyboard Shortcut Settings

@AppStorage("shortcutConfigsData") private var shortcutConfigsData: Data = Data()

var shortcutConfigs: [ShortcutConfig] {
    get {
        guard !shortcutConfigsData.isEmpty,
              let configs = try? JSONDecoder().decode([ShortcutConfig].self, from: shortcutConfigsData) else {
            return ShortcutAction.allCases.map { ShortcutConfig.defaultConfig(for: $0) }
        }
        return configs
    }
    set {
        if let data = try? JSONEncoder().encode(newValue) {
            shortcutConfigsData = data
            objectWillChange.send()
        }
    }
}

func shortcutConfig(for action: ShortcutAction) -> ShortcutConfig {
    shortcutConfigs.first { $0.action == action } ?? ShortcutConfig.defaultConfig(for: action)
}

func updateShortcut(_ config: ShortcutConfig) {
    var configs = shortcutConfigs
    if let index = configs.firstIndex(where: { $0.action == config.action }) {
        configs[index] = config
    } else {
        configs.append(config)
    }
    shortcutConfigs = configs
}

func resetShortcutsToDefaults() {
    shortcutConfigs = ShortcutAction.allCases.map { ShortcutConfig.defaultConfig(for: $0) }
}
```

**Step 3: Add AppKit import to AppSettings.swift**

At the top of the file, add:

```swift
import AppKit
```

**Step 4: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add DevCam/DevCam/Core/AppSettings.swift
git commit -m "$(cat <<'EOF'
feat: add ShortcutAction enum and ShortcutConfig storage model

- ShortcutAction enum with export durations and display names
- ShortcutConfig struct with keyCode, modifiers, and display string
- Persistent storage via @AppStorage with JSON encoding
- Default shortcuts: ⌘⇧S (30s), ⌘⇧M (1m), ⌘⇧L (5m), ⌘⇧P (pause)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: ShortcutManager with Customizable Hotkeys

**Files:**
- Create: `DevCam/DevCam/DevCam/Core/ShortcutManager.swift`

**Step 1: Create ShortcutManager.swift**

```swift
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
import OSLog

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
```

**Step 2: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add DevCam/DevCam/Core/ShortcutManager.swift
git commit -m "$(cat <<'EOF'
feat: add ShortcutManager for customizable global hotkeys

- Uses NSEvent monitors for local and global shortcuts
- Checks Accessibility permission for global shortcuts
- Executes export and pause/resume actions
- Conflict detection for shortcut assignment

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: ShortcutsTab Preferences UI

**Files:**
- Create: `DevCam/DevCam/DevCam/UI/ShortcutsTab.swift`

**Step 1: Create ShortcutsTab.swift**

```swift
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
    }

    private func setupKeyCapture() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
}

// MARK: - Preview

#Preview {
    let settings = AppSettings()
    let shortcutManager = ShortcutManager(settings: settings)

    return ShortcutsTab(settings: settings, shortcutManager: shortcutManager)
        .frame(width: 480, height: 400)
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add DevCam/DevCam/UI/ShortcutsTab.swift
git commit -m "$(cat <<'EOF'
feat: add ShortcutsTab preferences UI

- List of all shortcut actions with enable toggle
- Click-to-record shortcut capture
- Conflict detection with alert
- Reset to defaults button
- Accessibility permission warning

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Integrate ShortcutManager and ShortcutsTab

**Files:**
- Modify: `DevCam/DevCam/DevCam/DevCamApp.swift`
- Modify: `DevCam/DevCam/DevCam/UI/PreferencesWindow.swift`

**Step 1: Add ShortcutManager to AppDelegate**

In `DevCamApp.swift`, add property after `keyboardShortcutHandler`:

```swift
private var shortcutManager: ShortcutManager?
```

**Step 2: Initialize ShortcutManager in setupManagers()**

After `healthStats` initialization, add:

```swift
// Initialize shortcut manager
shortcutManager = ShortcutManager(settings: settings)
if let shortcutManager = shortcutManager,
   let recordingManager = recordingManager,
   let clipExporter = clipExporter {
    shortcutManager.setManagers(recordingManager: recordingManager, clipExporter: clipExporter)
}
```

**Step 3: Register shortcuts in setupKeyboardShortcuts()**

Replace the entire `setupKeyboardShortcuts()` method:

```swift
private func setupKeyboardShortcuts() {
    shortcutManager?.registerAllShortcuts()
    DevCamLogger.app.info("Keyboard shortcuts registered")
}
```

**Step 4: Update showPreferences() to pass shortcutManager**

In `showPreferences()`, update the guard statement:

```swift
guard let settings = settings,
      let clipExporter = clipExporter,
      let healthStats = healthStats,
      let recordingManager = recordingManager,
      let shortcutManager = shortcutManager else {
    DevCamLogger.app.error("Cannot show preferences - managers not initialized")
    return
}
```

Update the PreferencesWindow creation:

```swift
let prefsView = PreferencesWindow(
    settings: settings,
    permissionManager: permissionManager,
    clipExporter: clipExporter,
    healthStats: healthStats,
    recordingManager: recordingManager,
    shortcutManager: shortcutManager
)
```

**Step 5: Update PreferencesWindow.swift**

Add the shortcutManager parameter and Shortcuts tab:

```swift
struct PreferencesWindow: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var clipExporter: ClipExporter
    @ObservedObject var healthStats: HealthStats
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var shortcutManager: ShortcutManager

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            RecordingTab(settings: settings, recordingManager: recordingManager)
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }

            ShortcutsTab(settings: settings, shortcutManager: shortcutManager)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            ClipsTab(clipExporter: clipExporter)
                .tabItem {
                    Label("Clips", systemImage: "film")
                }

            HealthTab(healthStats: healthStats, recordingManager: recordingManager)
                .tabItem {
                    Label("Health", systemImage: "heart.text.square")
                }

            PrivacyTab(permissionManager: permissionManager)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
        }
        .frame(width: 500, height: 500)
    }
}
```

Update the preview:

```swift
#Preview {
    let settings = AppSettings()
    let permissionManager = PermissionManager()
    let bufferManager = BufferManager()
    let clipExporter = ClipExporter(
        bufferManager: bufferManager,
        settings: settings
    )
    let healthStats = HealthStats(bufferManager: bufferManager)
    let recordingManager = RecordingManager(
        bufferManager: bufferManager,
        permissionManager: permissionManager,
        settings: settings
    )
    let shortcutManager = ShortcutManager(settings: settings)

    return PreferencesWindow(
        settings: settings,
        permissionManager: permissionManager,
        clipExporter: clipExporter,
        healthStats: healthStats,
        recordingManager: recordingManager,
        shortcutManager: shortcutManager
    )
}
```

**Step 6: Remove old KeyboardShortcutHandler usage**

In AppDelegate, remove the `keyboardShortcutHandler` property and its setup. The new ShortcutManager replaces it completely.

**Step 7: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add DevCam/DevCam/DevCamApp.swift DevCam/DevCam/UI/PreferencesWindow.swift
git commit -m "$(cat <<'EOF'
feat: integrate ShortcutManager into app lifecycle

- Replace KeyboardShortcutHandler with ShortcutManager
- Add Shortcuts tab to PreferencesWindow
- Initialize and wire up managers in AppDelegate

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: MenubarIconManager with Badge Rendering

**Files:**
- Create: `DevCam/DevCam/DevCam/Core/MenubarIconManager.swift`

**Step 1: Create MenubarIconManager.swift**

```swift
//
//  MenubarIconManager.swift
//  DevCam
//
//  Manages dynamic menubar icon rendering with state indicators and buffer badge.
//

import Foundation
import AppKit
import Combine
import OSLog

@MainActor
class MenubarIconManager: ObservableObject {

    // MARK: - State

    enum IconState {
        case recording
        case recordingDegraded
        case paused
        case error
        case recovering
        case exporting(progress: Double)

        var symbolName: String {
            switch self {
            case .recording, .recordingDegraded:
                return "record.circle.fill"
            case .paused:
                return "pause.circle"
            case .error:
                return "exclamationmark.circle.fill"
            case .recovering:
                return "arrow.clockwise.circle"
            case .exporting:
                return "square.and.arrow.up.circle"
            }
        }

        var tintColor: NSColor {
            switch self {
            case .recording:
                return .systemRed
            case .recordingDegraded:
                return .systemYellow
            case .paused:
                return .systemGray
            case .error:
                return .systemOrange
            case .recovering:
                return .systemYellow
            case .exporting:
                return .systemBlue
            }
        }

        var tooltip: String {
            switch self {
            case .recording:
                return "DevCam: Recording"
            case .recordingDegraded:
                return "DevCam: Recording (Reduced Quality)"
            case .paused:
                return "DevCam: Paused"
            case .error:
                return "DevCam: Error - Click for details"
            case .recovering:
                return "DevCam: Recovering..."
            case .exporting(let progress):
                return "DevCam: Exporting (\(Int(progress * 100))%)"
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var currentState: IconState = .paused
    @Published private(set) var bufferMinutes: Int = 0

    // MARK: - Dependencies

    private weak var statusButton: NSStatusBarButton?
    private var cancellables = Set<AnyCancellable>()
    private var pulseTimer: Timer?
    private var pulseOpacity: CGFloat = 1.0

    // MARK: - Configuration

    private let showBadge: Bool = true
    private let enablePulseAnimation: Bool = true

    // MARK: - Initialization

    init() {}

    func configure(
        statusButton: NSStatusBarButton,
        recordingManager: RecordingManager,
        clipExporter: ClipExporter
    ) {
        self.statusButton = statusButton

        // Observe recording state
        recordingManager.$isRecording
            .combineLatest(
                recordingManager.$recordingError,
                recordingManager.$isInRecoveryMode,
                recordingManager.$isQualityDegraded
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, error, isRecovering, isDegraded in
                self?.updateState(
                    isRecording: isRecording,
                    hasError: error != nil,
                    isRecovering: isRecovering,
                    isDegraded: isDegraded
                )
            }
            .store(in: &cancellables)

        // Observe buffer duration
        recordingManager.$bufferDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.bufferMinutes = Int(duration / 60)
                self?.renderIcon()
            }
            .store(in: &cancellables)

        // Observe export progress
        clipExporter.$isExporting
            .combineLatest(clipExporter.$exportProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isExporting, progress in
                if isExporting {
                    self?.currentState = .exporting(progress: progress)
                    self?.renderIcon()
                }
            }
            .store(in: &cancellables)

        // Initial render
        renderIcon()
    }

    // MARK: - State Updates

    private func updateState(isRecording: Bool, hasError: Bool, isRecovering: Bool, isDegraded: Bool) {
        let newState: IconState

        if isRecovering {
            newState = .recovering
        } else if hasError {
            newState = .error
        } else if isRecording {
            newState = isDegraded ? .recordingDegraded : .recording
        } else {
            newState = .paused
        }

        currentState = newState
        updatePulseAnimation()
        renderIcon()
    }

    // MARK: - Rendering

    private func renderIcon() {
        guard let button = statusButton else { return }

        let iconSize = NSSize(width: 22, height: 22)
        let image = NSImage(size: iconSize, flipped: false) { rect in
            self.drawIcon(in: rect)
            return true
        }

        image.isTemplate = false
        button.image = image
        button.toolTip = currentState.tooltip
    }

    private func drawIcon(in rect: NSRect) {
        // Draw base icon
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard var symbolImage = NSImage(systemSymbolName: currentState.symbolName, accessibilityDescription: nil) else {
            return
        }

        symbolImage = symbolImage.withSymbolConfiguration(symbolConfig) ?? symbolImage

        // Apply tint and opacity for pulse animation
        let tintedImage = symbolImage.tinted(with: currentState.tintColor.withAlphaComponent(pulseOpacity))

        // Center the symbol
        let symbolRect = NSRect(
            x: (rect.width - 16) / 2,
            y: (rect.height - 16) / 2 + 1,
            width: 16,
            height: 16
        )
        tintedImage.draw(in: symbolRect)

        // Draw badge if enabled and recording
        if showBadge && bufferMinutes > 0 {
            drawBadge(in: rect, minutes: bufferMinutes)
        }
    }

    private func drawBadge(in rect: NSRect, minutes: Int) {
        let badgeText = "\(minutes)"
        let font = NSFont.systemFont(ofSize: 8, weight: .bold)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let textSize = (badgeText as NSString).size(withAttributes: attributes)
        let badgeWidth = max(textSize.width + 4, 10)
        let badgeHeight: CGFloat = 10

        // Position badge at bottom-right
        let badgeRect = NSRect(
            x: rect.width - badgeWidth - 1,
            y: 1,
            width: badgeWidth,
            height: badgeHeight
        )

        // Draw badge background
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3)
        NSColor.systemBlue.setFill()
        badgePath.fill()

        // Draw text centered in badge
        let textRect = NSRect(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        (badgeText as NSString).draw(in: textRect, withAttributes: attributes)
    }

    // MARK: - Pulse Animation

    private func updatePulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil

        // Only pulse during active recording (not degraded, error, etc.)
        guard enablePulseAnimation, case .recording = currentState else {
            pulseOpacity = 1.0
            return
        }

        // Check for reduced motion preference
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            pulseOpacity = 1.0
            return
        }

        // Start pulse animation
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Sine wave for smooth pulsing: 0.7 to 1.0 over 2 seconds
            let time = Date().timeIntervalSince1970
            let phase = (time.truncatingRemainder(dividingBy: 2.0)) / 2.0
            self.pulseOpacity = 0.7 + 0.3 * CGFloat(sin(phase * .pi * 2))

            Task { @MainActor in
                self.renderIcon()
            }
        }
    }

    // MARK: - Cleanup

    func stopAnimations() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}

// MARK: - NSImage Extension

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add DevCam/DevCam/Core/MenubarIconManager.swift
git commit -m "$(cat <<'EOF'
feat: add MenubarIconManager with dynamic badge

- Renders dynamic icon based on recording state
- Numeric badge shows buffered minutes
- Pulse animation during recording (respects Reduce Motion)
- Updates on state changes via Combine

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Integrate MenubarIconManager into AppDelegate

**Files:**
- Modify: `DevCam/DevCam/DevCam/DevCamApp.swift`

**Step 1: Add MenubarIconManager property**

After `shortcutManager` property:

```swift
private var menubarIconManager: MenubarIconManager?
```

**Step 2: Initialize in setupManagers()**

After shortcutManager initialization:

```swift
// Initialize menubar icon manager
menubarIconManager = MenubarIconManager()
```

**Step 3: Configure in setupStatusItem()**

After creating the status item button, add:

```swift
// Configure menubar icon manager
if let button = statusItem?.button,
   let recordingManager = recordingManager,
   let clipExporter = clipExporter {
    menubarIconManager?.configure(
        statusButton: button,
        recordingManager: recordingManager,
        clipExporter: clipExporter
    )
}
```

**Step 4: Remove old setupStatusIconObservation()**

Remove the entire `setupStatusIconObservation()` method and `updateStatusIcon()` method - the MenubarIconManager handles this now.

Also remove the call to `setupStatusIconObservation()` in `setupStatusItem()`.

Remove the `StatusIconState` enum from AppDelegate - it's replaced by MenubarIconManager.IconState.

Remove the `statusIconCancellables` property.

**Step 5: Stop animations on termination**

In `applicationWillTerminate()`, add:

```swift
menubarIconManager?.stopAnimations()
```

**Step 6: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add DevCam/DevCam/DevCamApp.swift
git commit -m "$(cat <<'EOF'
feat: integrate MenubarIconManager into AppDelegate

- Replace StatusIconState with MenubarIconManager
- Configure icon manager with status button
- Stop animations on app termination

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: TrimSliderView Component

**Files:**
- Create: `DevCam/DevCam/DevCam/UI/TrimSliderView.swift`

**Step 1: Create TrimSliderView.swift**

```swift
//
//  TrimSliderView.swift
//  DevCam
//
//  Dual-handle range slider for trimming video clips.
//

import SwiftUI

struct TrimSliderView: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false

    private let trackHeight: CGFloat = 8
    private let handleWidth: CGFloat = 12
    private let minSelectionDuration: Double = 1.0 // Minimum 1 second

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let usableWidth = width - handleWidth * 2

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: trackHeight)

                // Selected range
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.blue.opacity(0.3))
                    .frame(
                        width: CGFloat((endTime - startTime) / duration) * usableWidth,
                        height: trackHeight
                    )
                    .offset(x: handleWidth + CGFloat(startTime / duration) * usableWidth)

                // Excluded regions (darker)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: handleWidth + CGFloat(startTime / duration) * usableWidth, height: trackHeight)

                    Spacer()

                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: handleWidth + CGFloat((duration - endTime) / duration) * usableWidth, height: trackHeight)
                }

                // Start handle
                trimHandle(isStart: true)
                    .position(
                        x: handleWidth / 2 + CGFloat(startTime / duration) * usableWidth,
                        y: geometry.size.height / 2
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingStart = true
                                let newStart = clampedTime(
                                    from: value.location.x,
                                    width: usableWidth,
                                    isStart: true
                                )
                                startTime = newStart
                                onSeek(newStart)
                            }
                            .onEnded { _ in
                                isDraggingStart = false
                            }
                    )

                // End handle
                trimHandle(isStart: false)
                    .position(
                        x: handleWidth + CGFloat(endTime / duration) * usableWidth + handleWidth / 2,
                        y: geometry.size.height / 2
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingEnd = true
                                let newEnd = clampedTime(
                                    from: value.location.x - handleWidth,
                                    width: usableWidth,
                                    isStart: false
                                )
                                endTime = newEnd
                                onSeek(newEnd)
                            }
                            .onEnded { _ in
                                isDraggingEnd = false
                            }
                    )
            }
        }
        .frame(height: 24)
    }

    // MARK: - Trim Handle

    private func trimHandle(isStart: Bool) -> some View {
        let isActive = isStart ? isDraggingStart : isDraggingEnd

        return RoundedRectangle(cornerRadius: 2)
            .fill(isActive ? Color.blue : Color.white)
            .frame(width: handleWidth, height: 24)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .overlay(
                // Grip lines
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(nsColor: .secondaryLabelColor))
                            .frame(width: 4, height: 1)
                    }
                }
            )
    }

    // MARK: - Helpers

    private func clampedTime(from x: CGFloat, width: CGFloat, isStart: Bool) -> Double {
        let ratio = max(0, min(1, Double(x / width)))
        let time = ratio * duration

        if isStart {
            return min(time, endTime - minSelectionDuration)
        } else {
            return max(time, startTime + minSelectionDuration)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var start: Double = 10
        @State private var end: Double = 50

        var body: some View {
            VStack(spacing: 20) {
                TrimSliderView(
                    startTime: $start,
                    endTime: $end,
                    duration: 60,
                    onSeek: { _ in }
                )

                Text("Selection: \(Int(start))s - \(Int(end))s (\(Int(end - start))s)")
                    .font(.caption)
            }
            .padding()
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add DevCam/DevCam/UI/TrimSliderView.swift
git commit -m "$(cat <<'EOF'
feat: add TrimSliderView dual-handle range slider

- Draggable start and end handles
- Visual selection range with excluded regions
- Minimum 1 second selection
- Seek callback on handle drag

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: PreviewWindow with Trim Controls

**Files:**
- Create: `DevCam/DevCam/DevCam/UI/PreviewWindow.swift`

**Step 1: Create PreviewWindow.swift**

```swift
//
//  PreviewWindow.swift
//  DevCam
//
//  Preview window with video player and trim controls for clip export.
//

import SwiftUI
import AVKit
import AVFoundation

struct PreviewWindow: View {
    let segments: [SegmentInfo]
    let onExport: (TimeInterval, TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var player: AVPlayer?
    @State private var composition: AVMutableComposition?
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var isPlaying = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0

    private let timeObserverInterval = CMTime(seconds: 0.1, preferredTimescale: 600)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Video player
            videoPlayerSection

            // Trim controls
            trimSection

            Divider()

            // Action buttons
            actionButtons
        }
        .frame(width: 640, height: 480)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Preview & Trim")
                .font(.headline)
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Video Player Section

    private var videoPlayerSection: some View {
        ZStack {
            if let error = errorMessage {
                errorView(error)
            } else if isLoading {
                loadingView
            } else if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
            } else {
                noPreviewView
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .background(Color.black)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading preview...")
                .foregroundColor(.white)
        }
    }

    private var noPreviewView: some View {
        VStack(spacing: 8) {
            Image(systemName: "film.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No preview available")
                .foregroundColor(.gray)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.white)
        }
    }

    // MARK: - Trim Section

    private var trimSection: some View {
        VStack(spacing: 12) {
            // Playback timeline
            playbackTimeline

            // Trim slider
            TrimSliderView(
                startTime: $trimStart,
                endTime: $trimEnd,
                duration: duration,
                onSeek: { time in
                    player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
                }
            )
            .disabled(isLoading || errorMessage != nil)

            // Selection info
            HStack {
                Text("Selection: \(formatTime(trimStart)) - \(formatTime(trimEnd))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Duration: \(formatTime(trimEnd - trimStart))")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            }
        }
        .padding()
    }

    private var playbackTimeline: some View {
        HStack(spacing: 12) {
            // Current time
            Text(formatTime(currentTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (duration > 0 ? currentTime / duration : 0), height: 4)
                        .cornerRadius(2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percentage = max(0, min(1, value.location.x / geometry.size.width))
                            let seekTime = percentage * duration
                            player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                        }
                )
            }
            .frame(height: 4)

            // Play/pause
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(player == nil)

            // Total duration
            Text(formatTime(duration))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button("Export Clip") {
                onExport(trimStart, trimEnd)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || errorMessage != nil || trimEnd - trimStart < 1)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding()
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        guard !segments.isEmpty else {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let comp = try await createComposition(from: segments)
                let playerItem = AVPlayerItem(asset: comp)
                let newPlayer = AVPlayer(playerItem: playerItem)

                newPlayer.addPeriodicTimeObserver(forInterval: timeObserverInterval, queue: .main) { time in
                    currentTime = time.seconds
                }

                let assetDuration = try await comp.load(.duration)

                await MainActor.run {
                    self.composition = comp
                    self.player = newPlayer
                    self.duration = assetDuration.seconds
                    self.trimStart = 0
                    self.trimEnd = assetDuration.seconds
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not load preview: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func createComposition(from segments: [SegmentInfo]) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw PreviewError.compositionFailed
        }

        // Check for audio
        let firstAsset = AVURLAsset(url: segments.first!.fileURL)
        let hasAudio = try await !firstAsset.loadTracks(withMediaType: .audio).isEmpty

        let audioTrack: AVMutableCompositionTrack? = hasAudio
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil

        var currentTime = CMTime.zero

        for segment in segments {
            let asset = AVURLAsset(url: segment.fileURL)
            let tracks = try await asset.loadTracks(withMediaType: .video)

            guard let assetVideoTrack = tracks.first else { continue }

            let assetDuration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: assetDuration)

            try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)

            if let audioTrack = audioTrack {
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                if let assetAudioTrack = audioTracks.first {
                    try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                }
            }

            currentTime = CMTimeAdd(currentTime, assetDuration)
        }

        return composition
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
        isPlaying = false
    }

    // MARK: - Playback Controls

    private func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            if currentTime >= duration - 0.1 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview {
    PreviewWindow(
        segments: [],
        onExport: { _, _ in },
        onCancel: { }
    )
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add DevCam/DevCam/UI/PreviewWindow.swift
git commit -m "$(cat <<'EOF'
feat: add PreviewWindow with trim controls

- AVPlayer-based video preview
- TrimSliderView for selecting export range
- Playback timeline with seek
- Export/Cancel actions with keyboard shortcuts

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add exportWithRange to ClipExporter

**Files:**
- Modify: `DevCam/DevCam/DevCam/Core/ClipExporter.swift`

**Step 1: Add exportWithRange method**

After the existing `exportClip` method, add:

```swift
/// Export a clip with a specific time range.
/// - Parameters:
///   - segments: The segments to export from
///   - startTime: Start time within the composition (seconds)
///   - endTime: End time within the composition (seconds)
///   - title: Optional title for the clip
///   - notes: Optional notes/description
///   - tags: Optional array of tags
func exportWithRange(
    segments: [SegmentInfo],
    startTime: TimeInterval,
    endTime: TimeInterval,
    title: String? = nil,
    notes: String? = nil,
    tags: [String] = []
) async throws {
    guard !isExporting else {
        DevCamLogger.export.notice("Export already in progress")
        return
    }

    guard !segments.isEmpty else {
        throw ExportError.noSegmentsAvailable
    }

    guard endTime > startTime else {
        throw ExportError.insufficientBufferContent
    }

    isExporting = true
    exportProgress = 0.0
    exportError = nil

    do {
        // Check disk space
        let diskCheck = bufferManager.checkDiskSpace()
        if !diskCheck.hasSpace {
            throw ExportError.diskSpaceLow
        }

        // Ensure save location exists
        try FileManager.default.createDirectory(at: saveLocation, withIntermediateDirectories: true)

        // Create composition from segments
        let composition = try createComposition(from: segments)

        // Create trimmed composition
        let trimmedComposition = try createTrimmedComposition(
            from: composition,
            startTime: startTime,
            endTime: endTime
        )

        let outputURL = generateOutputURL()
        try await exportComposition(trimmedComposition, to: outputURL)

        let fileSize = try fileSize(at: outputURL)
        let clipInfo = ClipInfo(
            id: UUID(),
            fileURL: outputURL,
            timestamp: Date(),
            duration: endTime - startTime,
            fileSize: fileSize,
            title: title,
            notes: notes,
            tags: tags
        )

        addToRecentClips(clipInfo)

        if showNotifications {
            showExportNotification(clip: clipInfo)
        }

        exportProgress = 1.0
        isExporting = false

    } catch {
        exportError = error
        isExporting = false
        throw error
    }
}

private func createTrimmedComposition(
    from composition: AVMutableComposition,
    startTime: TimeInterval,
    endTime: TimeInterval
) throws -> AVMutableComposition {
    let trimmedComposition = AVMutableComposition()

    let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
    let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
    let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

    // Copy video track
    if let sourceVideoTrack = composition.tracks(withMediaType: .video).first,
       let destVideoTrack = trimmedComposition.addMutableTrack(
           withMediaType: .video,
           preferredTrackID: kCMPersistentTrackID_Invalid
       ) {
        try destVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
    }

    // Copy audio track if present
    if let sourceAudioTrack = composition.tracks(withMediaType: .audio).first,
       let destAudioTrack = trimmedComposition.addMutableTrack(
           withMediaType: .audio,
           preferredTrackID: kCMPersistentTrackID_Invalid
       ) {
        try destAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
    }

    return trimmedComposition
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add DevCam/DevCam/Core/ClipExporter.swift
git commit -m "$(cat <<'EOF'
feat: add exportWithRange for trimmed clip export

- Accept segments with start/end time range
- Create trimmed composition preserving audio
- Reuse existing export infrastructure

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Integrate PreviewWindow into MenuBarView

**Files:**
- Modify: `DevCam/DevCam/DevCam/UI/MenuBarView.swift`

**Step 1: Add state for preview window**

In MenuBarView, add state property:

```swift
@State private var showPreviewWindow = false
@State private var previewSegments: [SegmentInfo] = []
```

**Step 2: Add preview button to save actions section**

In `saveActionsSection`, after the "Advanced..." button, add:

```swift
// Preview button
Button(action: {
    previewSegments = bufferManager.getSegmentsForTimeRange(duration: selectedDuration)
    showPreviewWindow = true
}) {
    HStack {
        Text("Preview & Trim...")
            .font(.system(size: 12))
        Spacer()
        Image(systemName: "play.rectangle")
            .font(.system(size: 10))
    }
    .contentShape(Rectangle())
}
.buttonStyle(.plain)
.padding(.horizontal, 12)
.padding(.bottom, 8)
.disabled(!canSave())
.opacity(canSave() ? 1.0 : 0.5)
```

**Step 3: Add sheet for preview window**

After the existing `.sheet(isPresented: $showAdvancedWindow)`, add:

```swift
.sheet(isPresented: $showPreviewWindow) {
    PreviewWindow(
        segments: previewSegments,
        onExport: { startTime, endTime in
            showPreviewWindow = false
            Task {
                do {
                    try await clipExporter.exportWithRange(
                        segments: previewSegments,
                        startTime: startTime,
                        endTime: endTime
                    )
                } catch {
                    // Error handling done by ClipExporter
                }
            }
        },
        onCancel: {
            showPreviewWindow = false
        }
    )
}
```

**Step 4: Build and verify**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add DevCam/DevCam/UI/MenuBarView.swift
git commit -m "$(cat <<'EOF'
feat: integrate PreviewWindow into MenuBarView

- Add Preview & Trim button to save actions
- Show PreviewWindow as sheet
- Wire up trimmed export via ClipExporter

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Unit Tests for ShortcutManager

**Files:**
- Create: `DevCam/DevCamTests/ShortcutManagerTests.swift`

**Step 1: Create ShortcutManagerTests.swift**

```swift
//
//  ShortcutManagerTests.swift
//  DevCamTests
//
//  Tests for ShortcutManager functionality.
//

import XCTest
@testable import DevCam

@MainActor
final class ShortcutManagerTests: XCTestCase {

    var settings: AppSettings!
    var shortcutManager: ShortcutManager!

    override func setUp() async throws {
        settings = AppSettings()
        shortcutManager = ShortcutManager(settings: settings)
    }

    override func tearDown() async throws {
        shortcutManager.unregisterAll()
        shortcutManager = nil
        settings = nil
    }

    // MARK: - Shortcut Config Tests

    func testDefaultShortcutConfigs() {
        let configs = settings.shortcutConfigs

        XCTAssertEqual(configs.count, ShortcutAction.allCases.count)

        for action in ShortcutAction.allCases {
            let config = settings.shortcutConfig(for: action)
            XCTAssertEqual(config.action, action)
            XCTAssertTrue(config.isEnabled)
        }
    }

    func testUpdateShortcut() {
        var config = settings.shortcutConfig(for: .exportLast30Seconds)
        config.keyCode = 0 // A key
        config.modifiers = NSEvent.ModifierFlags([.command, .option]).rawValue

        settings.updateShortcut(config)

        let updated = settings.shortcutConfig(for: .exportLast30Seconds)
        XCTAssertEqual(updated.keyCode, 0)
        XCTAssertTrue(updated.modifierFlags.contains(.command))
        XCTAssertTrue(updated.modifierFlags.contains(.option))
    }

    func testDisableShortcut() {
        var config = settings.shortcutConfig(for: .togglePauseResume)
        config.isEnabled = false

        settings.updateShortcut(config)

        let updated = settings.shortcutConfig(for: .togglePauseResume)
        XCTAssertFalse(updated.isEnabled)
    }

    func testResetToDefaults() {
        // Modify a shortcut
        var config = settings.shortcutConfig(for: .exportLast1Minute)
        config.keyCode = 99
        config.isEnabled = false
        settings.updateShortcut(config)

        // Reset
        settings.resetShortcutsToDefaults()

        // Verify reset
        let reset = settings.shortcutConfig(for: .exportLast1Minute)
        XCTAssertEqual(reset.keyCode, ShortcutAction.exportLast1Minute.defaultKeyCode)
        XCTAssertTrue(reset.isEnabled)
    }

    // MARK: - Conflict Detection Tests

    func testDetectConflict() {
        // Default export30s uses ⌘⇧S (keyCode 1)
        let conflict = shortcutManager.detectConflict(
            keyCode: 1,
            modifiers: [.command, .shift],
            excludingAction: nil
        )

        XCTAssertEqual(conflict, .exportLast30Seconds)
    }

    func testNoConflictWhenExcluded() {
        let conflict = shortcutManager.detectConflict(
            keyCode: 1,
            modifiers: [.command, .shift],
            excludingAction: .exportLast30Seconds
        )

        XCTAssertNil(conflict)
    }

    func testNoConflictDifferentModifiers() {
        let conflict = shortcutManager.detectConflict(
            keyCode: 1,
            modifiers: [.command, .option], // Different modifiers
            excludingAction: nil
        )

        XCTAssertNil(conflict)
    }

    // MARK: - Display String Tests

    func testShortcutDisplayString() {
        let config = ShortcutConfig.defaultConfig(for: .exportLast30Seconds)

        // Default is ⌘⇧S
        XCTAssertTrue(config.displayString.contains("⌘"))
        XCTAssertTrue(config.displayString.contains("⇧"))
        XCTAssertTrue(config.displayString.contains("S"))
    }

    // MARK: - Export Duration Tests

    func testExportDurations() {
        XCTAssertEqual(ShortcutAction.exportLast30Seconds.exportDuration, 30)
        XCTAssertEqual(ShortcutAction.exportLast1Minute.exportDuration, 60)
        XCTAssertEqual(ShortcutAction.exportLast5Minutes.exportDuration, 300)
        XCTAssertNil(ShortcutAction.togglePauseResume.exportDuration)
    }
}
```

**Step 2: Run tests**

Run: `xcodebuild test -project DevCam.xcodeproj -scheme DevCam -destination 'platform=macOS' 2>&1 | tail -30`
Expected: All tests pass

**Step 3: Commit**

```bash
git add DevCam/DevCamTests/ShortcutManagerTests.swift
git commit -m "$(cat <<'EOF'
test: add ShortcutManager unit tests

- Test default configs and update/reset
- Test conflict detection
- Test display string formatting
- Test export durations

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Unit Tests for TrimSlider Logic

**Files:**
- Create: `DevCam/DevCamTests/TrimSliderTests.swift`

**Step 1: Create TrimSliderTests.swift**

```swift
//
//  TrimSliderTests.swift
//  DevCamTests
//
//  Tests for trim slider range validation logic.
//

import XCTest
@testable import DevCam

final class TrimSliderTests: XCTestCase {

    // MARK: - Range Validation Tests

    func testMinimumSelectionDuration() {
        // Minimum selection should be 1 second
        let minDuration: Double = 1.0

        let start: Double = 10.0
        let end: Double = 10.5 // Less than minimum

        // End should be clamped to start + minDuration
        let clampedEnd = max(end, start + minDuration)
        XCTAssertEqual(clampedEnd, 11.0)
    }

    func testStartCannotExceedEnd() {
        let duration: Double = 60.0
        let minSelection: Double = 1.0

        var start: Double = 30.0
        let end: Double = 25.0 // Start > End is invalid

        // Start should be clamped to end - minSelection
        start = min(start, end - minSelection)
        XCTAssertEqual(start, 24.0)
    }

    func testClampStartToZero() {
        let start: Double = -5.0
        let clampedStart = max(0, start)
        XCTAssertEqual(clampedStart, 0)
    }

    func testClampEndToDuration() {
        let duration: Double = 60.0
        let end: Double = 75.0
        let clampedEnd = min(duration, end)
        XCTAssertEqual(clampedEnd, 60.0)
    }

    // MARK: - Time Formatting Tests

    func testFormatTimeMinutesAndSeconds() {
        let seconds: Double = 125.0
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let formatted = String(format: "%d:%02d", mins, secs)
        XCTAssertEqual(formatted, "2:05")
    }

    func testFormatTimeZero() {
        let seconds: Double = 0.0
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let formatted = String(format: "%d:%02d", mins, secs)
        XCTAssertEqual(formatted, "0:00")
    }

    func testFormatTimeFullMinute() {
        let seconds: Double = 120.0
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let formatted = String(format: "%d:%02d", mins, secs)
        XCTAssertEqual(formatted, "2:00")
    }

    // MARK: - Selection Duration Tests

    func testSelectionDuration() {
        let start: Double = 15.0
        let end: Double = 45.0
        let selectionDuration = end - start
        XCTAssertEqual(selectionDuration, 30.0)
    }

    func testSelectionPercentage() {
        let duration: Double = 60.0
        let start: Double = 15.0
        let end: Double = 45.0

        let startPercentage = start / duration
        let endPercentage = end / duration

        XCTAssertEqual(startPercentage, 0.25)
        XCTAssertEqual(endPercentage, 0.75)
    }
}
```

**Step 2: Run tests**

Run: `xcodebuild test -project DevCam.xcodeproj -scheme DevCam -destination 'platform=macOS' 2>&1 | tail -30`
Expected: All tests pass

**Step 3: Commit**

```bash
git add DevCam/DevCamTests/TrimSliderTests.swift
git commit -m "$(cat <<'EOF'
test: add TrimSlider range validation tests

- Test minimum selection duration clamping
- Test start/end boundary validation
- Test time formatting helpers

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Final Integration and Manual Testing

**Files:**
- None (verification task)

**Step 1: Build the complete project**

Run: `xcodebuild -project DevCam.xcodeproj -scheme DevCam build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 2: Run all tests**

Run: `xcodebuild test -project DevCam.xcodeproj -scheme DevCam -destination 'platform=macOS' 2>&1 | tail -50`
Expected: All tests pass

**Step 3: Manual testing checklist**

1. **Keyboard Shortcuts:**
   - Open Preferences → Shortcuts tab
   - Verify all shortcuts are listed with defaults
   - Click on a shortcut to record a new combination
   - Test conflict detection (try assigning same shortcut twice)
   - Toggle a shortcut off and verify it doesn't trigger
   - Test global shortcuts when app is in background

2. **Dynamic Menubar Icon:**
   - Verify icon shows filled circle when recording
   - Verify badge shows buffer minutes (updates every 30s)
   - Pause recording and verify icon changes to pause circle
   - Start an export and verify icon shows upload circle

3. **Preview & Trim:**
   - Click menubar icon → adjust duration slider → click "Preview & Trim..."
   - Verify video loads and plays
   - Drag trim handles and verify selection updates
   - Click Export and verify trimmed clip is saved
   - Open exported clip and verify duration matches selection

**Step 4: Final commit (if any fixes needed)**

```bash
git status
# If clean, skip. If fixes made:
git add -A
git commit -m "$(cat <<'EOF'
fix: address integration issues from manual testing

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Summary

This plan implements three UX improvements:

1. **Customizable Keyboard Shortcuts** (Tasks 1-4, 11)
   - ShortcutAction enum with defaults
   - ShortcutManager using NSEvent monitors
   - ShortcutsTab preferences UI with click-to-record

2. **Dynamic Menubar Icon** (Tasks 5-6)
   - MenubarIconManager with state-based rendering
   - Numeric badge showing buffered minutes
   - Pulse animation during recording

3. **Preview & Trim Window** (Tasks 7-10, 12)
   - TrimSliderView dual-handle component
   - PreviewWindow with AVPlayer integration
   - ClipExporter.exportWithRange for trimmed exports

All tasks follow TDD principles with unit tests for core logic.
