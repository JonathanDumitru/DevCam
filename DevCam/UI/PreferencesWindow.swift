//
//  PreferencesWindow.swift
//  DevCam
//
//  Main preferences container with tabbed interface
//

import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var clipExporter: ClipExporter

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ClipsTab(clipExporter: clipExporter)
                .tabItem {
                    Label("Clips", systemImage: "film")
                }

            PrivacyTab(permissionManager: permissionManager)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Preview

#Preview {
    let settings = AppSettings()
    let permissionManager = PermissionManager()
    let bufferManager = BufferManager()
    let clipExporter = ClipExporter(
        bufferManager: bufferManager,
        settings: settings
    )

    return PreferencesWindow(
        settings: settings,
        permissionManager: permissionManager,
        clipExporter: clipExporter
    )
}
