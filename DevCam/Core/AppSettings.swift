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
        print("⚙️ DEBUG: AppSettings.init() - recordingQuality = \(recordingQuality.rawValue) (scale: \(recordingQuality.scaleFactor))")

        // CRITICAL FIX: @AppStorage with enums defaults to first case (.low) if key doesn't exist
        // Force set to .medium if we detect it's stuck on .low without an explicit user choice
        let storedValue = UserDefaults.standard.object(forKey: "recordingQuality")
        print("⚙️ DEBUG: UserDefaults.standard.object(forKey: \"recordingQuality\") = \(String(describing: storedValue))")

        if recordingQuality == .low {
            // Check if this is truly unset (no value in UserDefaults)
            if storedValue == nil {
                print("⚙️ DEBUG: No quality setting found, defaulting incorrectly to .low, forcing to .medium")
                recordingQuality = .medium
            } else {
                print("⚙️ DEBUG: Quality explicitly set to .low by user (stored value: \(String(describing: storedValue)))")
            }
        }

        // Ensure save location exists
        let location = saveLocation
        try? FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
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

    // MARK: - Launch at Login

    /// Configures launch at login preference.
    ///
    /// **Implementation Status**: Currently only stores the user preference in UserDefaults.
    /// Full implementation requires creating a LaunchAgent plist at:
    /// ~/Library/LaunchAgents/com.devcam.launcher.plist
    ///
    /// The plist should specify:
    /// - Program path to DevCam.app
    /// - RunAtLoad = true
    /// - KeepAlive = false (launch once, not a daemon)
    ///
    /// Future work: Use SMLoginItemSetEnabled (deprecated) or ServiceManagement framework
    /// to register/unregister the launch agent automatically.
    func configureLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled

        // Note: Actual launch agent configuration would require additional setup
        // For now, this just stores the preference
        // Full implementation would create/remove a LaunchAgent plist in ~/Library/LaunchAgents/

        if enabled {
            DevCamLogger.settings.info("Launch at login enabled (not yet implemented)")
        } else {
            DevCamLogger.settings.info("Launch at login disabled")
        }
    }
}
