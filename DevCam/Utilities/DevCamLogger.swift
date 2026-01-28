import OSLog
import UserNotifications

enum DevCamLogger {
    static let subsystem = "Jonathan-Hines-Dumitru.DevCam"
    static let app = Logger(subsystem: subsystem, category: "App")
    static let recording = Logger(subsystem: subsystem, category: "Recording")
    static let export = Logger(subsystem: subsystem, category: "Export")
    static let permissions = Logger(subsystem: subsystem, category: "Permissions")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let alerts = Logger(subsystem: subsystem, category: "Alerts")
}

// MARK: - Critical Alert Notifications

/// Sends user-visible notifications for critical errors that require attention.
/// These are system notifications that appear even when the app is in the background.
enum CriticalAlertManager {

    /// Alert types with user-friendly messages
    enum AlertType {
        case recordingStopped(reason: String)
        case diskSpaceLow(availableMB: Int)
        case diskSpaceCritical
        case exportFailed(reason: String)
        case permissionRevoked
        case qualityDegraded(from: RecordingQuality, to: RecordingQuality)
        case recordingRecovered

        var title: String {
            switch self {
            case .recordingStopped:
                return "Recording Stopped"
            case .diskSpaceLow:
                return "Low Disk Space Warning"
            case .diskSpaceCritical:
                return "Recording Stopped - No Disk Space"
            case .exportFailed:
                return "Clip Export Failed"
            case .permissionRevoked:
                return "Screen Recording Permission Required"
            case .qualityDegraded:
                return "Recording Quality Reduced"
            case .recordingRecovered:
                return "Recording Recovered"
            }
        }

        var body: String {
            switch self {
            case .recordingStopped(let reason):
                return "DevCam stopped recording: \(reason). Click to restart."
            case .diskSpaceLow(let availableMB):
                return "Only \(availableMB) MB of disk space remaining. Consider freeing up space."
            case .diskSpaceCritical:
                return "Recording stopped due to insufficient disk space. Free up space and restart DevCam."
            case .exportFailed(let reason):
                return "Could not save clip: \(reason)"
            case .permissionRevoked:
                return "DevCam needs screen recording permission to work. Click to open Settings."
            case .qualityDegraded(let from, let to):
                return "Recording quality reduced from \(from.displayName) to \(to.displayName) due to system constraints."
            case .recordingRecovered:
                return "DevCam automatically recovered and resumed recording."
            }
        }
    }

    /// Sends a critical alert notification to the user
    static func sendAlert(_ alertType: AlertType) {
        DevCamLogger.alerts.warning("Critical alert: \(alertType.title) - \(alertType.body)")

        let content = UNMutableNotificationContent()
        content.title = alertType.title
        content.body = alertType.body
        content.sound = .default

        // Use alert type as identifier to prevent duplicate notifications
        let identifier = "devcam-alert-\(String(describing: alertType).prefix(30))"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DevCamLogger.alerts.error("Failed to send critical alert: \(error.localizedDescription)")
            }
        }
    }

    /// Requests notification permission for critical alerts
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                DevCamLogger.alerts.error("Notification permission request failed: \(error.localizedDescription)")
            } else if !granted {
                DevCamLogger.alerts.warning("User denied notification permissions - critical alerts will not be shown")
            }
        }
    }
}
