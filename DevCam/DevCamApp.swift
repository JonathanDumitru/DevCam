//
//  DevCamApp.swift
//  DevCam
//
//  Created by Jonathan Hines Dumitru on 1/22/26.
//

import SwiftUI
import OSLog

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
    private var bufferManager: BufferManager!
    private var recordingManager: RecordingManager!
    private var clipExporter: ClipExporter!
    private var keyboardShortcutHandler: KeyboardShortcutHandler!
    private var menuBarPopover: NSPopover?
    private var settings: AppSettings!
    private var preferencesWindow: NSWindow?

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
        NSLog("🚀 DEBUG: applicationDidFinishLaunching() STARTED")
        print("🚀 DEBUG: applicationDidFinishLaunching() STARTED")
        DevCamLogger.app.info("Application launching")

        // Initialize permission manager (must be done on MainActor)
        print("🚀 DEBUG: Initializing PermissionManager on MainActor")
        permissionManager.initialize()
        print("✅ DEBUG: PermissionManager initialized")

        // Initialize managers (works in both normal and test mode)
        print("🚀 DEBUG: About to call setupManagers()")
        setupManagers()
        print("✅ DEBUG: setupManagers() COMPLETED")

        // Skip UI setup in test environment
        if isTestMode {
            print("⚠️ DEBUG: Running in TEST MODE - skipping UI setup")
            DevCamLogger.app.info("Running in test mode, skipping UI setup")
            return
        }

        // CRITICAL FIX (2026-01-25): Menubar icon visibility
        // Hide dock icon - handled by LSUIElement=true in Info.plist
        // IMPORTANT: Do NOT call NSApp.setActivationPolicy(.accessory) here!
        // Using BOTH LSUIElement=true AND setActivationPolicy(.accessory) causes
        // macOS to interpret the app as having NO UI at all, hiding the menubar icon.
        // LSUIElement=true alone is the correct approach for menubar-only apps.
        print("🚀 DEBUG: LSUIElement=true in Info.plist handles dock icon hiding")

        // Setup UI
        print("🚀 DEBUG: About to call setupStatusItem()")
        setupStatusItem()
        print("✅ DEBUG: setupStatusItem() COMPLETED")

        print("🚀 DEBUG: About to call setupKeyboardShortcuts()")
        setupKeyboardShortcuts()
        print("✅ DEBUG: setupKeyboardShortcuts() COMPLETED")

        // Start recording automatically
        print("🚀 DEBUG: About to call startRecording()")
        startRecording()
        print("✅ DEBUG: startRecording() call initiated (async)")

        print("🎉 DEBUG: applicationDidFinishLaunching() COMPLETED")
    }

    private func startRecording() {
        print("🎬 DEBUG: startRecording() - Creating Task")
        Task { @MainActor in
            print("🎬 DEBUG: Inside Task @MainActor")
            do {
                print("🎬 DEBUG: About to call recordingManager.startRecording()")
                try await recordingManager.startRecording()
                print("✅ DEBUG: recordingManager.startRecording() SUCCEEDED")
                DevCamLogger.recording.info("Recording started successfully")
            } catch {
                print("❌ DEBUG: recordingManager.startRecording() FAILED with error: \(error)")
                DevCamLogger.recording.error("Failed to start recording: \(String(describing: error), privacy: .public)")
                // Error will be set internally by RecordingManager
            }
        }
    }

    private func setupStatusItem() {
        print("📍 DEBUG: setupStatusItem() - Creating status bar item")
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("📍 DEBUG: NSStatusBar.system.statusItem returned: \(statusItem != nil ? "SUCCESS" : "NIL")")

        if let button = statusItem?.button {
            print("📍 DEBUG: Got status item button, setting image")
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "DevCam")
            print("📍 DEBUG: Button image set: \(button.image != nil ? "SUCCESS" : "NIL")")
            button.action = #selector(statusItemClicked)
            button.target = self
            print("✅ DEBUG: Status item fully configured - action and target set")
            DevCamLogger.app.info("Status item created")
        } else {
            print("❌ DEBUG: FAILED to get status item button - statusItem.button is NIL")
            DevCamLogger.app.error("Failed to get status item button")
        }
    }

    @objc func statusItemClicked() {
        print("🖱️ DEBUG: statusItemClicked() - Menubar icon clicked")
        guard let button = statusItem?.button else {
            print("❌ DEBUG: No button found")
            return
        }

        // If popover is already shown, just close it
        if let popover = menuBarPopover, popover.isShown {
            print("🖱️ DEBUG: Popover already shown, closing it")
            popover.close()
            return
        }

        // CRITICAL FIX: Always recreate popover with fresh manager references
        // This prevents stale @ObservedObject references from causing crashes
        print("🖱️ DEBUG: Closing existing popover if present")
        menuBarPopover?.close()
        menuBarPopover = nil

        // Verify managers exist
        print("🖱️ DEBUG: Checking managers before creating MenuBarView")
        print("   recordingManager: \(recordingManager != nil ? "OK" : "NIL")")
        print("   clipExporter: \(clipExporter != nil ? "OK" : "NIL")")

        guard let recordingManager = recordingManager,
              let clipExporter = clipExporter else {
            print("❌ ERROR: Cannot create menubar view - managers not initialized!")
            return
        }

        print("🖱️ DEBUG: Creating new popover with fresh manager references")
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 300)
        popover.behavior = .transient

        // Create MenuBarView with validated managers
        print("🖱️ DEBUG: Creating MenuBarView with validated managers")
        let menuView = MenuBarView(
            recordingManager: recordingManager,
            clipExporter: clipExporter,
            onPreferences: { [weak self] in
                self?.menuBarPopover?.close()
                self?.showPreferences()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        print("✅ DEBUG: MenuBarView created")

        popover.contentViewController = NSHostingController(rootView: menuView)
        menuBarPopover = popover
        print("✅ DEBUG: Popover created and assigned")

        // Show the newly created popover
        print("🖱️ DEBUG: Showing popover")
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        print("✅ DEBUG: Popover shown")
    }

    private func setupKeyboardShortcuts() {
        keyboardShortcutHandler = KeyboardShortcutHandler()
        keyboardShortcutHandler.registerShortcuts(
            onSave5Minutes: { [weak self] in
                Task { @MainActor [weak self] in
                    try? await self?.clipExporter.exportClip(duration: 300)
                }
            },
            onSave10Minutes: { [weak self] in
                Task { @MainActor [weak self] in
                    try? await self?.clipExporter.exportClip(duration: 600)
                }
            },
            onSave15Minutes: { [weak self] in
                Task { @MainActor [weak self] in
                    try? await self?.clipExporter.exportClip(duration: 900)
                }
            }
        )
        DevCamLogger.app.info("Keyboard shortcuts registered")
    }

    func applicationWillTerminate(_ notification: Notification) {
        DevCamLogger.app.info("Application terminating")
        Task { @MainActor in
            await recordingManager.stopRecording()
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
        print("⚙️ DEBUG: setupManagers() - Creating AppSettings")
        settings = AppSettings()
        print("⚙️ DEBUG: AppSettings created: \(settings != nil ? "SUCCESS" : "FAILED")")
        assert(settings != nil, "CRITICAL: AppSettings is nil after creation!")

        print("⚙️ DEBUG: Creating BufferManager")
        bufferManager = BufferManager()
        print("⚙️ DEBUG: BufferManager created: \(bufferManager != nil ? "SUCCESS" : "FAILED")")
        assert(bufferManager != nil, "CRITICAL: BufferManager is nil after creation!")

        print("⚙️ DEBUG: Creating RecordingManager")
        recordingManager = RecordingManager(
            bufferManager: bufferManager,
            permissionManager: permissionManager,
            settings: settings
        )
        print("⚙️ DEBUG: RecordingManager created: \(recordingManager != nil ? "SUCCESS" : "FAILED")")
        assert(recordingManager != nil, "CRITICAL: RecordingManager is nil after creation!")

        print("⚙️ DEBUG: Creating ClipExporter")
        clipExporter = ClipExporter(
            bufferManager: bufferManager,
            saveLocation: settings.saveLocation,
            showNotifications: settings.showNotifications
        )
        print("⚙️ DEBUG: ClipExporter created: \(clipExporter != nil ? "SUCCESS" : "FAILED")")
        assert(clipExporter != nil, "CRITICAL: ClipExporter is nil after creation!")

        print("✅ DEBUG: All managers initialized successfully")
        print("   settings: \(settings != nil ? "✅" : "❌")")
        print("   bufferManager: \(bufferManager != nil ? "✅" : "❌")")
        print("   recordingManager: \(recordingManager != nil ? "✅" : "❌")")
        print("   clipExporter: \(clipExporter != nil ? "✅" : "❌")")
        DevCamLogger.app.info("Managers initialized")
    }

    private func showPreferences() {
        print("🪟 DEBUG: showPreferences() - Opening preferences window")

        // Verify managers are initialized
        print("🪟 DEBUG: Checking manager initialization...")
        print("🪟 DEBUG: settings = \(settings != nil ? "initialized" : "NIL")")
        print("🪟 DEBUG: clipExporter = \(clipExporter != nil ? "initialized" : "NIL")")

        guard let settings = settings,
              let clipExporter = clipExporter else {
            print("❌ ERROR: Cannot show preferences - managers not initialized!")
            print("   settings: \(settings != nil ? "OK" : "NIL")")
            print("   clipExporter: \(clipExporter != nil ? "OK" : "NIL")")
            return
        }

        // CRITICAL FIX: Always recreate window with fresh manager references
        // This prevents stale @ObservedObject references from causing crashes
        print("🪟 DEBUG: Closing existing preferences window if present")
        preferencesWindow?.close()
        preferencesWindow = nil

        print("🪟 DEBUG: Creating new preferences window with fresh manager references")
        let prefsView = PreferencesWindow(
            settings: settings,
            permissionManager: permissionManager,
            clipExporter: clipExporter
        )
        print("✅ DEBUG: PreferencesWindow view created")

        print("🪟 DEBUG: Creating NSWindow")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        print("✅ DEBUG: NSWindow created")

        window.title = "DevCam Preferences"
        window.center()
        print("🪟 DEBUG: Setting NSHostingView as content view")
        window.contentView = NSHostingView(rootView: prefsView)
        print("✅ DEBUG: NSHostingView set")
        window.isReleasedWhenClosed = false

        preferencesWindow = window
        print("✅ DEBUG: Preferences window created and assigned")

        // Show window
        print("🪟 DEBUG: Calling makeKeyAndOrderFront")
        window.makeKeyAndOrderFront(nil)
        print("✅ DEBUG: Preferences window should now be visible")
        NSApp.activate(ignoringOtherApps: true)
    }
}
