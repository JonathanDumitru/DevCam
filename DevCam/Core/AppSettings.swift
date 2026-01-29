//
//  AppSettings.swift
//  DevCam
//
//  Manages user preferences and application settings
//

import Foundation
import SwiftUI
import Combine
import OSLog
import AVFoundation
import AppKit

/// Recording quality levels that determine resolution scaling and performance impact.
///
/// **Performance vs Quality:**
/// - **Low (720p):** Best performance, ~75% smaller files, recommended for long sessions
/// - **Medium (1080p):** Balanced quality and performance, good for most use cases
/// - **High (Native):** Maximum quality, highest resource usage, best for demos/tutorials
///
/// The quality setting affects the captured resolution by scaling the display dimensions.
/// Lower quality = lower resolution = less CPU/GPU load and smaller file sizes.
enum RecordingQuality: String, CaseIterable, Identifiable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .low: return "Low (720p)"
        case .medium: return "Medium (1080p)"
        case .high: return "High (Native Resolution)"
        }
    }

    /// Scale factor applied to display dimensions
    var scaleFactor: Double {
        switch self {
        case .low: return 0.5      // ~720p from 1440p, or 540p from 1080p
        case .medium: return 0.75  // ~1080p from 1440p, or 810p from 1080p
        case .high: return 1.0     // Native resolution
        }
    }

    /// Human-readable description for UI
    var description: String {
        switch self {
        case .low:
            return "Best performance, smaller files (~25% of native resolution)"
        case .medium:
            return "Balanced quality and performance (~56% of native resolution)"
        case .high:
            return "Maximum quality, highest resource usage (100% native resolution)"
        }
    }

    /// Returns the next lower quality level for graceful degradation.
    /// Returns nil if already at lowest quality.
    var lowerQuality: RecordingQuality? {
        switch self {
        case .high: return .medium
        case .medium: return .low
        case .low: return nil
        }
    }

    /// Priority order for degradation (high -> medium -> low)
    var degradationOrder: Int {
        switch self {
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }
}

/// Display selection mode for multi-monitor support
enum DisplaySelectionMode: String, CaseIterable, Identifiable, Codable {
    case primary = "primary"       // Largest/primary display
    case specific = "specific"     // User-selected display
    case all = "all"               // All displays (not yet implemented)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary: return "Primary Display"
        case .specific: return "Specific Display"
        case .all: return "All Displays"
        }
    }

    var description: String {
        switch self {
        case .primary: return "Record the largest connected display"
        case .specific: return "Record a specific display you select"
        case .all: return "Record all displays in a single video"
        }
    }
}

/// Audio capture mode for recordings
enum AudioCaptureMode: String, CaseIterable, Identifiable, Codable {
    case none = "none"
    case system = "system"
    case microphone = "microphone"
    case both = "both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No Audio"
        case .system: return "System Audio"
        case .microphone: return "Microphone"
        case .both: return "System + Microphone"
        }
    }

    var description: String {
        switch self {
        case .none: return "Record video only, no audio"
        case .system: return "Capture system sounds and app audio"
        case .microphone: return "Capture microphone input"
        case .both: return "Capture both system audio and microphone"
        }
    }

    var capturesSystemAudio: Bool {
        self == .system || self == .both
    }

    var capturesMicrophone: Bool {
        self == .microphone || self == .both
    }
}

/// Battery-aware recording mode
enum BatteryMode: String, CaseIterable, Identifiable, Codable {
    case ignore = "ignore"           // Ignore battery state
    case reduceQuality = "reduce"    // Reduce quality on battery
    case pauseOnLow = "pause"        // Pause when battery is low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ignore: return "Ignore Battery"
        case .reduceQuality: return "Reduce Quality on Battery"
        case .pauseOnLow: return "Pause on Low Battery"
        }
    }

    var description: String {
        switch self {
        case .ignore: return "Record at full quality regardless of battery state"
        case .reduceQuality: return "Automatically reduce quality when on battery power"
        case .pauseOnLow: return "Pause recording when battery drops below 20%"
        }
    }
}

/// Available frame rates for recording
enum FrameRate: Int, CaseIterable, Identifiable, Codable {
    case fps10 = 10
    case fps15 = 15
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }

    var displayName: String {
        "\(rawValue) fps"
    }

    var frameInterval: CMTime {
        CMTime(value: 1, timescale: CMTimeScale(rawValue))
    }
}

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

/// Manages user preferences and application settings with automatic persistence.
///
/// Uses @AppStorage property wrappers for automatic UserDefaults synchronization.
/// All setting changes are automatically persisted and published to SwiftUI views
/// that observe this object via @ObservedObject or @StateObject.
///
/// **Persistence Strategy**: @AppStorage properties automatically sync with UserDefaults,
/// so values persist across app launches. The `saveLocation` computed property converts
/// between String paths (stored in UserDefaults) and URL objects (used by the app).
@MainActor
class AppSettings: ObservableObject {

    // MARK: - Published Settings

    @AppStorage("saveLocation") private var saveLocationPath: String = ""
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("bufferSize") var bufferSize: Int = 900 // 15 minutes default
    @AppStorage("recordingQuality") var recordingQuality: RecordingQuality = .medium

    // MARK: - Display Settings (Phase 4)

    @AppStorage("displaySelectionMode") var displaySelectionMode: DisplaySelectionMode = .primary
    @AppStorage("selectedDisplayID") private var _selectedDisplayID: Int = 0

    /// The selected display ID for specific display mode.
    /// Stored as Int internally for @AppStorage compatibility.
    var selectedDisplayID: UInt32 {
        get { UInt32(_selectedDisplayID) }
        set { _selectedDisplayID = Int(newValue) }
    }

    // MARK: - Audio Settings (Phase 4)

    @AppStorage("audioCaptureMode") var audioCaptureMode: AudioCaptureMode = .none

    // MARK: - Battery Settings (Phase 4)

    @AppStorage("batteryMode") var batteryMode: BatteryMode = .ignore
    @AppStorage("lowBatteryThreshold") var lowBatteryThreshold: Int = 20 // Percent

    // MARK: - Adaptive Quality Settings (Phase 4)

    @AppStorage("adaptiveQualityEnabled") var adaptiveQualityEnabled: Bool = false
    @AppStorage("cpuThresholdHigh") var cpuThresholdHigh: Int = 80 // Reduce quality above this %
    @AppStorage("cpuThresholdLow") var cpuThresholdLow: Int = 50 // Restore quality below this %

    // MARK: - Frame Rate Settings

    @AppStorage("targetFrameRate") var targetFrameRate: FrameRate = .fps30
    @AppStorage("adaptiveFrameRateEnabled") var adaptiveFrameRateEnabled: Bool = false
    @AppStorage("idleThreshold") var idleThreshold: Double = 5.0 // seconds
    @AppStorage("idleFrameRate") var idleFrameRate: FrameRate = .fps10

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

    // Save location as URL
    var saveLocation: URL {
        get {
            if saveLocationPath.isEmpty {
                // Default: ~/Movies/DevCam/
                let moviesDir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
                return moviesDir.appendingPathComponent("DevCam")
            }
            return URL(fileURLWithPath: saveLocationPath)
        }
        set {
            saveLocationPath = newValue.path
            objectWillChange.send()
        }
    }

    // MARK: - Initialization

    init() {
        // CRITICAL FIX: @AppStorage with enums defaults to first case (.low) if key doesn't exist
        // Force set to .medium if we detect it's stuck on .low without an explicit user choice
        let storedValue = UserDefaults.standard.object(forKey: "recordingQuality")

        if recordingQuality == .low {
            // Check if this is truly unset (no value in UserDefaults)
            if storedValue == nil {
                recordingQuality = .medium
                DevCamLogger.settings.debug("No quality setting found, defaulting to .medium")
            } else {
                DevCamLogger.settings.debug("Quality explicitly set to .low by user")
            }
        }

        // Sync launch at login preference with system state
        // This handles cases where the user manually changed Login Items in System Settings
        let systemEnabled = LaunchAtLoginManager.shared.isEnabled
        if launchAtLogin != systemEnabled {
            launchAtLogin = systemEnabled
            DevCamLogger.settings.info("Synced launch at login preference with system state: \(systemEnabled)")
        }

        // Ensure save location exists
        let location = saveLocation
        do {
            try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
            DevCamLogger.settings.debug("Save location directory ensured: \(location.path)")
        } catch {
            DevCamLogger.settings.error("Failed to create save location directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Validation

    func validateSaveLocation() -> Bool {
        let location = saveLocation
        var isDirectory: ObjCBool = false

        // Check if path exists and is a directory
        guard FileManager.default.fileExists(atPath: location.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        // Check if writable
        return FileManager.default.isWritableFile(atPath: location.path)
    }

    // MARK: - Quality Degradation

    /// Temporary override for quality during degradation. If set, this takes precedence.
    private var degradedQuality: RecordingQuality?

    /// The effective quality to use for recording (considers degradation)
    var effectiveRecordingQuality: RecordingQuality {
        degradedQuality ?? recordingQuality
    }

    /// Sets a temporary degraded quality level. Use `resetDegradedQuality()` to restore.
    func setDegradedQuality(_ quality: RecordingQuality) {
        degradedQuality = quality
        DevCamLogger.settings.warning("Quality degraded to \(quality.displayName)")
        objectWillChange.send()
    }

    /// Resets degraded quality, restoring the user's configured quality.
    func resetDegradedQuality() {
        if degradedQuality != nil {
            DevCamLogger.settings.info("Quality restored to user setting: \(self.recordingQuality.displayName)")
            degradedQuality = nil
            objectWillChange.send()
        }
    }

    /// Returns true if quality is currently degraded below user setting.
    var isQualityDegraded: Bool {
        degradedQuality != nil
    }

    // MARK: - Launch at Login

    /// Configures launch at login preference using the ServiceManagement framework.
    ///
    /// **Implementation**: Uses `SMAppService.mainApp` (macOS 13+) to register/unregister
    /// the application as a login item in System Settings > General > Login Items.
    ///
    /// **Atomic Operation**: Both UserDefaults and system registration must succeed.
    /// If system registration fails, the UserDefaults preference is reverted.
    ///
    /// **Error Handling**: Logs errors and reverts the preference if registration fails.
    /// The UI layer should detect the revert to show appropriate feedback.
    func configureLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled

        do {
            if enabled {
                try LaunchAtLoginManager.shared.enable()
                DevCamLogger.settings.info("Launch at login enabled")
            } else {
                try LaunchAtLoginManager.shared.disable()
                DevCamLogger.settings.info("Launch at login disabled")
            }
        } catch {
            DevCamLogger.settings.error("Failed to configure launch at login: \(error.localizedDescription)")
            // Revert the preference if system registration failed
            launchAtLogin = !enabled
        }
    }
}
