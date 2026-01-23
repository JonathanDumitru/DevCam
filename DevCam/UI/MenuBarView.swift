//
//  MenuBarView.swift
//  DevCam
//
//  Menubar dropdown menu with save actions and settings
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var clipExporter: ClipExporter

    let onPreferences: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Status section
            statusSection

            Divider()

            // Save actions
            saveActionsSection

            Divider()

            // Settings
            settingsSection
        }
        .frame(width: 250)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 4) {
            HStack {
                statusIndicator
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }

            if recordingManager.isRecording {
                HStack {
                    Text(bufferStatusText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            if clipExporter.isExporting {
                VStack(spacing: 4) {
                    HStack {
                        Text("Exporting...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    ProgressView(value: clipExporter.exportProgress)
                        .progressViewStyle(.linear)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        if let error = recordingManager.recordingError {
            return .orange
        }
        return recordingManager.isRecording ? .red : .gray
    }

    private var statusText: String {
        if let error = recordingManager.recordingError {
            return "Error - \(error.localizedDescription)"
        }
        return recordingManager.isRecording ? "Recording" : "Paused"
    }

    private var bufferStatusText: String {
        let duration = recordingManager.bufferDuration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "Buffer: %d:%02d / 15:00", minutes, seconds)
    }

    // MARK: - Save Actions Section

    private var saveActionsSection: some View {
        VStack(spacing: 0) {
            saveButton(duration: 300, title: "Save Last 5 Minutes", shortcut: "⌘⇧5")
            saveButton(duration: 600, title: "Save Last 10 Minutes", shortcut: "⌘⇧6")
            saveButton(duration: 900, title: "Save Last 15 Minutes", shortcut: "⌘⇧7")
        }
    }

    private func saveButton(duration: TimeInterval, title: String, shortcut: String) -> some View {
        Button(action: {
            Task {
                do {
                    print("💾 DEBUG: Attempting to export \(duration) second clip")
                    try await clipExporter.exportClip(duration: duration)
                    print("✅ DEBUG: Export completed successfully")
                } catch {
                    print("❌ DEBUG: Export failed: \(error)")
                }
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Text(shortcut)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .disabled(!canSave(duration: duration))
        .opacity(canSave(duration: duration) ? 1.0 : 0.5)
    }

    private func canSave(duration: TimeInterval) -> Bool {
        // Can save if we have any buffer content and not currently exporting
        return recordingManager.bufferDuration > 0 && !clipExporter.isExporting
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 0) {
            Button("Preferences...") {
                onPreferences()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button("Quit DevCam") {
                onQuit()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Preview

#Preview {
    let bufferManager = BufferManager()
    let permissionManager = PermissionManager()
    let settings = AppSettings()
    let recordingManager = RecordingManager(
        bufferManager: bufferManager,
        permissionManager: permissionManager,
        settings: settings
    )
    let clipExporter = ClipExporter(
        bufferManager: bufferManager,
        saveLocation: nil,
        showNotifications: false
    )

    MenuBarView(
        recordingManager: recordingManager,
        clipExporter: clipExporter,
        onPreferences: { print("Preferences") },
        onQuit: { print("Quit") }
    )
}
