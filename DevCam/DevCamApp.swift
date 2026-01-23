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

    func applicationDidFinishLaunching(_ notification: Notification) {
        DevCamLogger.app.info("Application launching")

        // Initialize managers (works in both normal and test mode)
        setupManagers()

        // Skip UI setup in test environment
        if isTestMode {
            DevCamLogger.app.info("Running in test mode, skipping UI setup")
            return
        }

        // Hide dock icon - this is a menubar-only app
        NSApp.setActivationPolicy(.accessory)

        // Setup UI
        setupStatusItem()
        setupKeyboardShortcuts()

        // Start recording automatically
        startRecording()
    }

    private func startRecording() {
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
        } else {
            DevCamLogger.app.error("Failed to get status item button")
        }
    }

    @objc func statusItemClicked() {
        guard let button = statusItem?.button else { return }

        // Create popover if needed
        if menuBarPopover == nil {
            let popover = NSPopover()
            popover.contentSize = NSSize(width: 250, height: 300)
            popover.behavior = .transient

            // Create MenuBarView
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

            popover.contentViewController = NSHostingController(rootView: menuView)
            menuBarPopover = popover
        }

        // Toggle popover
        if let popover = menuBarPopover {
            if popover.isShown {
                popover.close()
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
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

    private func setupManagers() {
        settings = AppSettings()
        bufferManager = BufferManager()
        recordingManager = RecordingManager(
            bufferManager: bufferManager,
            permissionManager: permissionManager
        )
        clipExporter = ClipExporter(
            bufferManager: bufferManager,
            saveLocation: settings.saveLocation,
            showNotifications: settings.showNotifications
        )
        DevCamLogger.app.info("Managers initialized")
    }

    private func showPreferences() {
        // Create window if needed
        if preferencesWindow == nil {
            let prefsView = PreferencesWindow(
                settings: settings,
                permissionManager: permissionManager,
                clipExporter: clipExporter
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
        }

        // Show window
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
