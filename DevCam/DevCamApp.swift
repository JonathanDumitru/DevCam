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
        // Hide dock icon - this is a menubar-only app
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "DevCam")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc func statusItemClicked() {
        // TODO: Show menu
        print("Status item clicked")
    }
}
