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

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "DevCam")
            button.action = #selector(statusItemClicked)
            button.target = self
            NSLog("DevCam: Status item created with action and target set")
        } else {
            NSLog("DevCam: ERROR - Failed to get status item button!")
        }
    }

    @objc func statusItemClicked() {
        // TODO: Show menu
        print("Status item clicked")
        NSLog("DevCam: Status item clicked!")
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
        NSLog("DevCam: Managers initialized")
    }
}
