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
    @ObservedObject var healthStats: HealthStats
    @ObservedObject var recordingManager: RecordingManager

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

            HealthTab(healthStats: healthStats, recordingManager: recordingManager)
                .tabItem {
                    Label("Health", systemImage: "heart.text.square")
                }

            PrivacyTab(permissionManager: permissionManager)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
        }
        .frame(width: 500, height: 450)
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
    let healthStats = HealthStats(bufferManager: bufferManager)
    let recordingManager = RecordingManager(
        bufferManager: bufferManager,
        permissionManager: permissionManager,
        settings: settings
    )

    return PreferencesWindow(
        settings: settings,
        permissionManager: permissionManager,
        clipExporter: clipExporter,
        healthStats: healthStats,
        recordingManager: recordingManager
    )
}
