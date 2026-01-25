//
//  GeneralTab.swift
//  DevCam
//
//  General preferences: save location, launch at login, notifications
//

import SwiftUI

struct GeneralTab: View {
    @ObservedObject var settings: AppSettings
    @State private var initialQuality: RecordingQuality?

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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recording Quality")
                        .font(.headline)

                    Picker("Quality", selection: $settings.recordingQuality) {
                        ForEach(RecordingQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onAppear {
                        // Capture initial quality when view appears
                        if initialQuality == nil {
                            initialQuality = settings.recordingQuality
                        }
                    }

                    Text(settings.recordingQuality.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Only show warning if quality has actually changed from initial value
                    if let initial = initialQuality, settings.recordingQuality != initial {
                        Label("Restart DevCam to apply new quality setting", systemImage: "info.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }

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
