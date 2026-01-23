import Foundation
import Combine
import ScreenCaptureKit
import AppKit
import CoreGraphics
import OSLog

@MainActor
class PermissionManager: ObservableObject {
    @Published var hasScreenRecordingPermission: Bool = false

    // Allow disabling for testing
    var isTestMode: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        checkPermission()
    }

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
            return
        }

        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
