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
