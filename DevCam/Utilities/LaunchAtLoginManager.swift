//
//  LaunchAtLoginManager.swift
//  DevCam
//
//  Manages launch at login functionality using macOS ServiceManagement framework
//

import ServiceManagement

/// Manages launch at login functionality using the modern ServiceManagement API.
///
/// **Architecture Decision**: Uses `SMAppService.mainApp` which registers the main application
/// bundle itself as a login item, eliminating the need for a separate helper app or launch agent.
///
/// **Requirements**: macOS 13.0+ (Ventura)
///
/// **Usage**:
/// ```swift
/// try LaunchAtLoginManager.shared.enable()
/// try LaunchAtLoginManager.shared.disable()
/// let isEnabled = LaunchAtLoginManager.shared.isEnabled
/// ```
///
/// **Error Handling**: Both `enable()` and `disable()` throw errors if registration fails,
/// typically due to:
/// - Sandboxing restrictions (requires proper entitlements)
/// - System Settings security restrictions
/// - Invalid app bundle configuration
final class LaunchAtLoginManager {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = LaunchAtLoginManager()

    // MARK: - Properties

    /// The ServiceManagement service representing the main app as a login item
    private let service: SMAppService

    // MARK: - Initialization

    private init() {
        // SMAppService.mainApp uses the main application bundle
        // No helper app or agent required
        service = SMAppService.mainApp
    }

    // MARK: - Public API

    /// Returns whether launch at login is currently enabled in system settings.
    ///
    /// **Note**: This queries the actual system state, not just UserDefaults.
    /// Use this to detect manual changes made in System Settings > Login Items.
    var isEnabled: Bool {
        return service.status == .enabled
    }

    /// Enables launch at login by registering with the system.
    ///
    /// This adds the application to System Settings > General > Login Items.
    ///
    /// **Throws**: `NSError` if registration fails due to permissions or system restrictions.
    func enable() throws {
        try service.register()
    }

    /// Disables launch at login by unregistering from the system.
    ///
    /// This removes the application from System Settings > General > Login Items.
    ///
    /// **Throws**: `NSError` if unregistration fails.
    func disable() throws {
        try service.unregister()
    }
}
