//
//  DevCamApp.swift
//  DevCam
//
//  Created by Jonathan Hines Dumitru on 1/22/26.
//

import SwiftUI

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

    var isTestMode: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("DevCam: Application launching...")

        // Initialize managers (works in both normal and test mode)
        setupManagers()

        // Skip UI setup in test environment
        if isTestMode {
            NSLog("DevCam: Running in test mode, skipping UI setup")
            return
        }

        // Hide dock icon - this is a menubar-only app
        NSApp.setActivationPolicy(.accessory)

        // Setup UI
        setupStatusItem()
        setupKeyboardShortcuts()
    }

    private func setupStatusItem() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "DevCam")
            button.action = #selector(statusItemClicked)
            button.target = self
            NSLog("DevCam: Status item created")
        } else {
            NSLog("DevCam: ERROR - Failed to get status item button!")
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
                    // TODO: Show preferences window
                    self?.menuBarPopover?.close()
                    NSLog("DevCam: Show preferences")
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
        NSLog("DevCam: Keyboard shortcuts registered")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("DevCam: Application terminating...")
        Task { @MainActor in
            await recordingManager.stopRecording()
        }
    }

    private func setupManagers() {
        bufferManager = BufferManager()
        recordingManager = RecordingManager(
            bufferManager: bufferManager,
            permissionManager: permissionManager
        )
        clipExporter = ClipExporter(
            bufferManager: bufferManager,
            saveLocation: nil, // Uses default ~/Movies/DevCam/
            showNotifications: true
        )
        NSLog("DevCam: Managers initialized")
    }
}
