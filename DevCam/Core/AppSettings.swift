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
