//
//  PrivacyTab.swift
//  DevCam
//
//  Privacy settings and permission management
//

import SwiftUI

struct PrivacyTab: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Screen Recording Permission")
                        .font(.headline)

                    HStack {
                        permissionStatusIndicator

                        VStack(alignment: .leading, spacing: 4) {
                            Text(permissionStatusText)
                                .font(.system(size: 13))

                            Text(permissionStatusDescription)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !permissionManager.hasScreenRecordingPermission {
                            Button("Open System Settings") {
                                permissionManager.openSystemSettings()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.headline)

                    Text("DevCam stores all recordings locally on your Mac. No data is sent to the internet.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.vertical, 4)

                    Text("What We Store:")
                        .font(.system(size: 12, weight: .medium))

                    VStack(alignment: .leading, spacing: 4) {
                        privacyBullet("Screen recordings in a 15-minute rolling buffer")
                        privacyBullet("Exported clips at your chosen save location")
                        privacyBullet("User preferences (save location, settings)")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Text("What We Don't Store:")
                        .font(.system(size: 12, weight: .medium))

                    VStack(alignment: .leading, spacing: 4) {
                        privacyBullet("No cloud storage or backups")
                        privacyBullet("No analytics or telemetry")
                        privacyBullet("No user tracking")
                        privacyBullet("No internet connection required")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Text("Storage Locations:")
                        .font(.system(size: 12, weight: .medium))

                    VStack(alignment: .leading, spacing: 4) {
                        storageLocation(
                            label: "Buffer",
                            path: "~/Library/Application Support/DevCam/buffer/"
                        )
                        storageLocation(
                            label: "Clips",
                            path: "User-selected location (default: ~/Movies/DevCam/)"
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Permission Status

    private var permissionStatusIndicator: some View {
        Image(systemName: permissionStatusIcon)
            .font(.system(size: 24))
            .foregroundColor(permissionStatusColor)
    }

    private var permissionStatusIcon: String {
        permissionManager.hasScreenRecordingPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var permissionStatusColor: Color {
        permissionManager.hasScreenRecordingPermission ? .green : .orange
    }

    private var permissionStatusText: String {
        permissionManager.hasScreenRecordingPermission ? "Permission Granted" : "Permission Required"
    }

    private var permissionStatusDescription: String {
        if permissionManager.hasScreenRecordingPermission {
            return "DevCam can record your screen"
        } else {
            return "DevCam needs screen recording permission to function"
        }
    }

    // MARK: - Helper Views

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func storageLocation(label: String, path: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(label):")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacyTab(permissionManager: PermissionManager())
        .frame(width: 500, height: 400)
}
