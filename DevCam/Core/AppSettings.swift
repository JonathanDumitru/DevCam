//
//  AppSettings.swift
//  DevCam
//
//  Manages user preferences and application settings
//

import Foundation
import SwiftUI
import Combine

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

    func configureLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled

        // Note: Actual launch agent configuration would require additional setup
        // For now, this just stores the preference
        // Full implementation would create/remove a LaunchAgent plist in ~/Library/LaunchAgents/

        if enabled {
            NSLog("Launch at login enabled (not yet implemented)")
        } else {
            NSLog("Launch at login disabled")
        }
    }
}
