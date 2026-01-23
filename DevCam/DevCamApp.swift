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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("DevCam: Application launching...")

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
}
