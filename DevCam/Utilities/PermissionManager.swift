import Foundation
import Combine
import ScreenCaptureKit
import AppKit
import CoreGraphics
import OSLog

/// Manages screen recording permission state and requests.
///
/// **Permission Flow**:
/// 1. `CGPreflightScreenCaptureAccess()` - Check current permission (doesn't show dialog)
/// 2. `CGRequestScreenCaptureAccess()` - Request permission (shows system dialog once)
/// 3. User must manually enable in System Settings > Privacy & Security > Screen Recording
///
/// **Test Mode Behavior**: When running under XCTest, always grants permission automatically.
/// This allows tests to run without requiring manual permission grants on CI/test machines.
/// Test mode is detected by checking for XCTestConfigurationFilePath environment variable.
///
/// **Permission State**: Checked on initialization and stored in published property for
/// SwiftUI views to observe and react to permission changes.
@MainActor
class PermissionManager: ObservableObject {
    @Published var hasScreenRecordingPermission: Bool = false

    // Allow disabling for testing
    var isTestMode: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // CRITICAL: init must NOT be isolated to MainActor because it's called during
    // AppDelegate initialization, which may not be on MainActor yet.
    // We'll check permission later in a MainActor context.
    nonisolated init() {
    }

    // Call this after initialization to actually check permission
    func initialize() {
        checkPermission()
        DevCamLogger.settings.info("Permission check completed - hasScreenRecordingPermission: \(self.hasScreenRecordingPermission)")
    }

    /// Returns the current screen recording permission status.
    ///
    /// **Three possible states**:
    /// - "granted": CGPreflightScreenCaptureAccess returns true
    /// - "denied": User was asked before (tracked in UserDefaults) but permission not granted
    /// - "notDetermined": User has never been asked for permission yet
    ///
    /// **UserDefaults tracking**: We store "HasRequestedScreenRecording" to distinguish between
    /// "user denied permission" vs "user never asked" (both return false from CGPreflight).
    /// This allows UI to show appropriate messaging ("Request Permission" vs "Open Settings").
    func screenRecordingPermissionStatus() -> String {
        if isTestMode {
            // In test mode, return a valid status without calling CGPreflightScreenCaptureAccess
            return "notDetermined"
        }

        if CGPreflightScreenCaptureAccess() {
            return "granted"
        } else {
            // Check if we've requested before
            let hasRequested = UserDefaults.standard.bool(forKey: "HasRequestedScreenRecording")
            return hasRequested ? "denied" : "notDetermined"
        }
    }

    func requestScreenRecordingPermission() {
        if isTestMode {
            // Skip actual permission request in test mode
            return
        }

        UserDefaults.standard.set(true, forKey: "HasRequestedScreenRecording")
        let _ = CGRequestScreenCaptureAccess()
        checkPermission()
    }

    func checkPermission() {
        if isTestMode {
            // In test mode, grant permission by default to allow tests to run
            hasScreenRecordingPermission = true
            DevCamLogger.settings.debug("Test mode: granting screen recording permission")
            return
        }

        let result = CGPreflightScreenCaptureAccess()
        hasScreenRecordingPermission = result
        DevCamLogger.settings.debug("Screen recording permission: \(result ? "granted" : "not granted")")
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
