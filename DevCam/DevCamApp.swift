//
//  DevCamApp.swift
//  DevCam
//
//  Created by Jonathan Hines Dumitru on 1/22/26.
//

import SwiftUI
import OSLog
import Combine

@main
struct DevCamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private let permissionManager = PermissionManager()
    private var bufferManager: BufferManager?
    private var recordingManager: RecordingManager?
    private var clipExporter: ClipExporter?
    private var healthStats: HealthStats?
    private var keyboardShortcutHandler: KeyboardShortcutHandler?
    private var menuBarPopover: NSPopover?
    private var settings: AppSettings?
    private var preferencesWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    // Status icon observation
    private var statusIconCancellables = Set<AnyCancellable>()

    var isTestMode: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Application initialization flow on launch.
    ///
    /// **Initialization order (critical dependencies)**:
    /// 1. setupManagers() - Creates manager instances in dependency order
    /// 2. UI setup (if not test mode) - Status bar, keyboard shortcuts
    /// 3. Auto-start recording - Begins continuous background recording
    ///
    /// **Test mode detection**: When XCTestConfigurationFilePath environment variable exists,
    /// skips all UI setup (status bar, keyboard shortcuts) to allow headless testing.
    /// Managers are still initialized to support unit tests that need them.
    ///
    /// **Auto-start recording**: Recording starts automatically on launch to maintain the
    /// continuous 15-minute rolling buffer. Users don't need to manually start recording.
    func applicationDidFinishLaunching(_ notification: Notification) {
        DevCamLogger.app.info("Application launching")

        // Initialize permission manager (must be done on MainActor)
        permissionManager.initialize()

        // Initialize managers (works in both normal and test mode)
        setupManagers()

        // Skip UI setup in test environment
        if isTestMode {
            DevCamLogger.app.info("Running in test mode, skipping UI setup")
            return
        }

        // CRITICAL FIX (2026-01-25): Menubar icon visibility
        // Hide dock icon - handled by LSUIElement=true in Info.plist
        // IMPORTANT: Do NOT call NSApp.setActivationPolicy(.accessory) here!
        // Using BOTH LSUIElement=true AND setActivationPolicy(.accessory) causes
        // macOS to interpret the app as having NO UI at all, hiding the menubar icon.
        // LSUIElement=true alone is the correct approach for menubar-only apps.

        // Setup UI
        setupStatusItem()
        setupKeyboardShortcuts()

        // Show onboarding on first launch, otherwise start recording
        if !OnboardingView.hasCompletedOnboarding {
            showOnboarding()
        } else {
            // Start recording automatically
            startRecording()
        }
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let onboardingView = OnboardingView(
            permissionManager: permissionManager,
            onComplete: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                self?.startRecording()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to DevCam"
        window.center()
        window.contentView = NSHostingView(rootView: onboardingView)
        window.isReleasedWhenClosed = false

        onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startRecording() {
        guard let recordingManager = recordingManager else {
            DevCamLogger.recording.error("Cannot start recording: RecordingManager not initialized")
            return
        }

        Task { @MainActor in
            do {
                try await recordingManager.startRecording()
                DevCamLogger.recording.info("Recording started successfully")
            } catch {
                DevCamLogger.recording.error("Failed to start recording: \(String(describing: error), privacy: .public)")
                // Error will be set internally by RecordingManager
            }
        }
    }

    private func setupStatusItem() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "DevCam")
            button.action = #selector(statusItemClicked)
            button.target = self
            DevCamLogger.app.info("Status item created")

            // Setup status icon observation
            setupStatusIconObservation()
        } else {
            DevCamLogger.app.error("Failed to get status item button")
        }
    }

    // MARK: - Status Icon Management

    /// Sets up observation of RecordingManager state to update the menubar icon.
    private func setupStatusIconObservation() {
        guard let recordingManager = recordingManager else { return }

        // Observe recording state changes
        recordingManager.$isRecording
            .combineLatest(
                recordingManager.$recordingError,
                recordingManager.$isInRecoveryMode,
                recordingManager.$isQualityDegraded
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, error, isRecovering, isDegraded in
                self?.updateStatusIcon(
                    isRecording: isRecording,
                    hasError: error != nil,
                    isRecovering: isRecovering,
                    isDegraded: isDegraded
                )
            }
            .store(in: &statusIconCancellables)
    }

    /// Updates the menubar icon based on current state.
    private func updateStatusIcon(isRecording: Bool, hasError: Bool, isRecovering: Bool, isDegraded: Bool) {
        guard let button = statusItem?.button else { return }

        let iconState = StatusIconState.from(
            isRecording: isRecording,
            hasError: hasError,
            isRecovering: isRecovering,
            isDegraded: isDegraded
        )

        button.image = iconState.image
        button.toolTip = iconState.tooltip
    }

    /// Represents the different states of the menubar icon.
    enum StatusIconState {
        case recording
        case recordingDegraded
        case paused
        case error
        case recovering

        static func from(isRecording: Bool, hasError: Bool, isRecovering: Bool, isDegraded: Bool) -> StatusIconState {
            if isRecovering {
                return .recovering
            }
            if hasError {
                return .error
            }
            if isRecording {
                return isDegraded ? .recordingDegraded : .recording
            }
            return .paused
        }

        var image: NSImage? {
            let symbolName: String
            let accessibilityDescription: String

            switch self {
            case .recording:
                symbolName = "record.circle.fill"
                accessibilityDescription = "DevCam - Recording"
            case .recordingDegraded:
                symbolName = "record.circle"
                accessibilityDescription = "DevCam - Recording (Reduced Quality)"
            case .paused:
                symbolName = "pause.circle"
                accessibilityDescription = "DevCam - Paused"
            case .error:
                symbolName = "exclamationmark.circle.fill"
                accessibilityDescription = "DevCam - Error"
            case .recovering:
                symbolName = "arrow.clockwise.circle"
                accessibilityDescription = "DevCam - Recovering"
            }

            var image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)

            // Apply color tint based on state
            if let baseImage = image {
                let config = NSImage.SymbolConfiguration(paletteColors: [tintColor])
                image = baseImage.withSymbolConfiguration(config)
            }

            return image
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
            }
        }
    }

    @objc func statusItemClicked() {
        guard let button = statusItem?.button else {
            return
        }

        // If popover is already shown, just close it
        if let popover = menuBarPopover, popover.isShown {
            popover.close()
            return
        }

        // OPTIMIZATION: Reuse existing popover instead of recreating
        // This reduces energy spikes by avoiding NSPopover allocation and NSHostingController setup
        if let existingPopover = menuBarPopover {
            existingPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            return
        }

        // Verify managers exist
        guard let recordingManager = recordingManager,
              let clipExporter = clipExporter else {
            DevCamLogger.app.error("Cannot create menubar view - managers not initialized")
            return
        }

        // First time opening - create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 300)
        popover.behavior = .transient

        guard let bufferManager = bufferManager else {
            DevCamLogger.app.error("Cannot create menubar view - bufferManager not initialized")
            return
        }

        // Create MenuBarView with validated managers
        let menuView = MenuBarView(
            recordingManager: recordingManager,
            clipExporter: clipExporter,
            bufferManager: bufferManager,
            onPreferences: { [weak self] in
                self?.menuBarPopover?.close()
                self?.showPreferences()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        popover.contentViewController = NSHostingController(rootView: menuView)
        menuBarPopover = popover

        // Show the newly created popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func setupKeyboardShortcuts() {
        keyboardShortcutHandler = KeyboardShortcutHandler()
        keyboardShortcutHandler?.registerShortcuts(
            onSave5Minutes: { [weak self] in
                Task { @MainActor [weak self] in
                    do {
                        try await self?.clipExporter?.exportClip(duration: 300)
                        DevCamLogger.export.info("5-minute clip exported via keyboard shortcut")
                    } catch {
                        DevCamLogger.export.error("Failed to export 5-minute clip: \(error.localizedDescription)")
                    }
                }
            },
            onSave10Minutes: { [weak self] in
                Task { @MainActor [weak self] in
                    do {
                        try await self?.clipExporter?.exportClip(duration: 600)
                        DevCamLogger.export.info("10-minute clip exported via keyboard shortcut")
                    } catch {
                        DevCamLogger.export.error("Failed to export 10-minute clip: \(error.localizedDescription)")
                    }
                }
            },
            onSave15Minutes: { [weak self] in
                Task { @MainActor [weak self] in
                    do {
                        try await self?.clipExporter?.exportClip(duration: 900)
                        DevCamLogger.export.info("15-minute clip exported via keyboard shortcut")
                    } catch {
                        DevCamLogger.export.error("Failed to export 15-minute clip: \(error.localizedDescription)")
                    }
                }
            }
        )
        DevCamLogger.app.info("Keyboard shortcuts registered")
    }

    func applicationWillTerminate(_ notification: Notification) {
        DevCamLogger.app.info("Application terminating")

        // Save health stats before termination
        healthStats?.finalizeSession()

        Task { @MainActor in
            await recordingManager?.stopRecording()
        }
    }

    /// Initializes core manager instances in dependency order.
    ///
    /// **Manager dependency chain**:
    /// 1. AppSettings - No dependencies, stores user preferences
    /// 2. BufferManager - No dependencies, manages segment storage
    /// 3. RecordingManager - Depends on BufferManager (writes segments) and PermissionManager
    /// 4. ClipExporter - Depends on BufferManager (reads segments) and AppSettings
    ///
    /// This initialization order ensures that when RecordingManager starts recording,
    /// BufferManager is ready to receive segments. Similarly, ClipExporter can access
    /// segments once BufferManager is initialized.
    private func setupManagers() {
        settings = AppSettings()
        guard settings != nil else {
            DevCamLogger.app.fault("CRITICAL: AppSettings initialization failed")
            return
        }

        bufferManager = BufferManager()
        guard bufferManager != nil else {
            DevCamLogger.app.fault("CRITICAL: BufferManager initialization failed")
            return
        }

        guard let settings = settings, let bufferManager = bufferManager else {
            DevCamLogger.app.fault("CRITICAL: Required managers are nil")
            return
        }

        recordingManager = RecordingManager(
            bufferManager: bufferManager,
            permissionManager: permissionManager,
            settings: settings
        )
        guard recordingManager != nil else {
            DevCamLogger.app.fault("CRITICAL: RecordingManager initialization failed")
            return
        }

        clipExporter = ClipExporter(
            bufferManager: bufferManager,
            settings: settings
        )
        guard clipExporter != nil else {
            DevCamLogger.app.fault("CRITICAL: ClipExporter initialization failed")
            return
        }

        // Initialize health stats
        healthStats = HealthStats(bufferManager: bufferManager)
        if let healthStats = healthStats, let recordingManager = recordingManager {
            healthStats.setRecordingManager(recordingManager)
        }

        DevCamLogger.app.info("Managers initialized successfully")
    }

    private func showPreferences() {
        // Verify managers are initialized
        guard let settings = settings,
              let clipExporter = clipExporter,
              let healthStats = healthStats,
              let recordingManager = recordingManager else {
            DevCamLogger.app.error("Cannot show preferences - managers not initialized")
            return
        }

        // OPTIMIZATION: Reuse existing window instead of recreating
        // This reduces energy spikes by avoiding NSWindow allocation and NSHostingView setup
        if let existingWindow = preferencesWindow {
            // Window already exists - just show it
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // First time opening - create the window
        let prefsView = PreferencesWindow(
            settings: settings,
            permissionManager: permissionManager,
            clipExporter: clipExporter,
            healthStats: healthStats,
            recordingManager: recordingManager
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "DevCam Preferences"
        window.center()
        window.contentView = NSHostingView(rootView: prefsView)
        window.isReleasedWhenClosed = false

        preferencesWindow = window

        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
