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
    private var shortcutManager: ShortcutManager?
    private var menubarIconManager: MenubarIconManager?
    private var menuBarPopover: NSPopover?
    private var settings: AppSettings?
    private var windowCaptureManager: WindowCaptureManager?
    private var preferencesWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var overlayWindow: NSWindow?
    private var notificationObservers: [NSObjectProtocol] = []

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
        setupNotificationObservers()

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

            // Configure menubar icon manager
            if let button = statusItem?.button,
               let recordingManager = recordingManager,
               let clipExporter = clipExporter {
                menubarIconManager?.configure(
                    statusButton: button,
                    recordingManager: recordingManager,
                    clipExporter: clipExporter
                )
            }

            DevCamLogger.app.info("Status item created")
        } else {
            DevCamLogger.app.error("Failed to get status item button")
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
              let clipExporter = clipExporter,
              let windowCaptureManager = windowCaptureManager,
              let settings = settings else {
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
            windowCaptureManager: windowCaptureManager,
            settings: settings,
            onSelectWindows: { [weak self] in
                self?.menuBarPopover?.close()
                self?.showWindowSelectionPanel()
            },
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
        shortcutManager?.registerAllShortcuts()
        DevCamLogger.app.info("Keyboard shortcuts registered")
    }

    func applicationWillTerminate(_ notification: Notification) {
        DevCamLogger.app.info("Application terminating")

        menubarIconManager?.stopAnimations()

        // Remove notification observers
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

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

        windowCaptureManager = WindowCaptureManager(settings: settings)
        guard windowCaptureManager != nil else {
            DevCamLogger.app.fault("CRITICAL: WindowCaptureManager initialization failed")
            return
        }

        // Initialize health stats
        healthStats = HealthStats(bufferManager: bufferManager)
        if let healthStats = healthStats, let recordingManager = recordingManager {
            healthStats.setRecordingManager(recordingManager)
        }

        // Initialize shortcut manager
        shortcutManager = ShortcutManager(settings: settings)
        if let shortcutManager = shortcutManager,
           let recordingManager = recordingManager,
           let clipExporter = clipExporter {
            shortcutManager.setManagers(recordingManager: recordingManager, clipExporter: clipExporter)
        }

        // Initialize menubar icon manager
        menubarIconManager = MenubarIconManager()

        DevCamLogger.app.info("Managers initialized successfully")
    }

    private func showPreferences() {
        // Verify managers are initialized
        guard let settings = settings,
              let clipExporter = clipExporter,
              let healthStats = healthStats,
              let recordingManager = recordingManager,
              let shortcutManager = shortcutManager else {
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
            recordingManager: recordingManager,
            shortcutManager: shortcutManager
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

    private func showWindowSelectionPanel() {
        showWindowSelectionOverlay()
    }

    // MARK: - Window Selection Overlay

    private func setupNotificationObservers() {
        // Observe keyboard shortcut for opening window picker
        let observer = NotificationCenter.default.addObserver(
            forName: .openWindowPicker,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showWindowSelectionOverlay()
        }
        notificationObservers.append(observer)
        DevCamLogger.app.info("Notification observers registered")
    }

    func showWindowSelectionOverlay() {
        guard let windowCaptureManager = windowCaptureManager,
              let settings = settings else {
            DevCamLogger.app.error("Cannot show window selection: managers not initialized")
            return
        }

        // Close any existing overlay
        overlayWindow?.close()

        let overlay = WindowSelectionOverlay(
            windowCaptureManager: windowCaptureManager,
            settings: settings,
            onDismiss: { [weak self] in
                self?.dismissWindowSelectionOverlay()
            }
        )

        let hostingView = NSHostingView(rootView: overlay)

        // Create borderless full-screen window
        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.makeKeyAndOrderFront(nil)

        // Ensure the window accepts keyboard events
        window.makeFirstResponder(hostingView)

        overlayWindow = window
        DevCamLogger.app.info("Window selection overlay shown")
    }

    private func dismissWindowSelectionOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        DevCamLogger.app.info("Window selection overlay dismissed")
    }
}
