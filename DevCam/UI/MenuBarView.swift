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

    @State private var selectedDuration: Double = 300 // Default 5 minutes (in seconds)
    @State private var showAdvancedWindow = false

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
        .sheet(isPresented: $showAdvancedWindow) {
            AdvancedClipWindow(
                recordingManager: recordingManager,
                clipExporter: clipExporter
            )
        }
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
        VStack(spacing: 12) {
            // Title
            HStack {
                Text("Save Clip")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Duration slider
            VStack(spacing: 8) {
                Slider(value: $selectedDuration, in: 60...900, step: 60)
                    .padding(.horizontal, 12)

                HStack {
                    Text(formatDuration(selectedDuration))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Max: \(formatDuration(min(recordingManager.bufferDuration, 900)))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }

            // Save button
            Button(action: {
                Task {
                    do {
                        print("💾 DEBUG: Attempting to export \(selectedDuration) second clip")
                        try await clipExporter.exportClip(duration: selectedDuration)
                        print("✅ DEBUG: Export completed successfully")
                    } catch {
                        print("❌ DEBUG: Export failed: \(error)")
                    }
                }
            }) {
                Text("Save Clip")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 12)
            .disabled(!canSave())

            // Advanced button
            Button(action: {
                showAdvancedWindow = true
            }) {
                HStack {
                    Text("Advanced...")
                        .font(.system(size: 12))
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .disabled(!canSave())
            .opacity(canSave() ? 1.0 : 0.5)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 {
            return "\(minutes) min"
        } else {
            return "\(minutes):\(String(format: "%02d", secs))"
        }
    }

    private func canSave() -> Bool {
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
