//
//  GeneralTab.swift
//  DevCam
//
//  General preferences: save location, launch at login, notifications
//

import SwiftUI

struct GeneralTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save Location")
                        .font(.headline)

                    HStack {
                        Text(settings.saveLocation.path)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Choose...") {
                            chooseSaveLocation()
                        }
                    }

                    if !settings.validateSaveLocation() {
                        Label("Location is not writable", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
            }

            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        settings.configureLaunchAtLogin(newValue)
                    }

                Toggle("Show Notifications", isOn: $settings.showNotifications)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About DevCam")
                        .font(.headline)

                    Text("Version 1.0.0")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("A developer body camera for capturing screen activity")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Save Location"

        if panel.runModal() == .OK, let url = panel.url {
            settings.saveLocation = url
        }
    }
}

// MARK: - Preview

#Preview {
    GeneralTab(settings: AppSettings())
        .frame(width: 500, height: 400)
}
