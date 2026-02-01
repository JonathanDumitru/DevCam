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
    @ObservedObject var settings: AppSettings
    let bufferManager: BufferManager

    let onPreferences: () -> Void
    let onQuit: () -> Void

    @State private var selectedDuration: Double = 300 // Default 5 minutes (in seconds)
    @State private var showAdvancedWindow = false

    // Display selection state
    @State private var availableDisplays: [(id: UInt32, name: String, width: Int, height: Int)] = []
    @State private var showDisplaySwitchConfirmation = false
    @State private var pendingDisplaySwitch: UInt32?
    @State private var isSwitchingDisplay = false

    var body: some View {
        VStack(spacing: 0) {
            // Status section
            statusSection

            Divider()

            // Display selection (quick switch)
            displaySelectionSection

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
                clipExporter: clipExporter,
                bufferManager: bufferManager
            )
        }
        .sheet(isPresented: $showDisplaySwitchConfirmation) {
            if let displayID = pendingDisplaySwitch,
               let display = availableDisplays.first(where: { $0.id == displayID }) {
                DisplaySwitchConfirmationView(
                    targetDisplayName: "\(display.name) (\(display.width)×\(display.height))",
                    onConfirm: {
                        performDisplaySwitch(to: displayID)
                        showDisplaySwitchConfirmation = false
                        pendingDisplaySwitch = nil
                    },
                    onCancel: {
                        showDisplaySwitchConfirmation = false
                        pendingDisplaySwitch = nil
                    }
                )
            }
        }
        .task {
            availableDisplays = await recordingManager.getDisplayList()
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 4) {
            // Primary status row
            HStack {
                statusIndicator
                Text(statusText)
                    .font(.headline)
                Spacer()
            }

            // Secondary status indicators
            if recordingManager.isInRecoveryMode {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Auto-recovery in progress...")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }

            if recordingManager.isQualityDegraded {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Quality reduced due to system constraints")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // Buffer status
            if recordingManager.isRecording {
                HStack {
                    Text(bufferStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()

                    // Disk space indicator
                    diskSpaceIndicator
                }
            }

            // Export progress
            if clipExporter.isExporting {
                VStack(spacing: 4) {
                    HStack {
                        Text("Exporting...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    ProgressView(value: clipExporter.exportProgress)
                        .progressViewStyle(.linear)
                }
            }

            // Error details (if any)
            if let error = recordingManager.recordingError {
                HStack {
                    Text(errorDescription(error))
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .lineLimit(2)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Display Selection Section

    private var displaySelectionSection: some View {
        VStack(spacing: 4) {
            Menu {
                ForEach(availableDisplays, id: \.id) { display in
                    Button {
                        handleDisplaySelection(display.id)
                    } label: {
                        HStack {
                            Text("\(display.name) (\(display.width)×\(display.height))")
                            if display.id == currentDisplayID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(display.id == currentDisplayID)
                }

                if availableDisplays.isEmpty {
                    Text("No displays detected")
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack {
                    Image(systemName: "display")
                        .font(.caption)
                    Text(currentDisplayLabel)
                        .font(.body)
                    Spacer()
                    if isSwitchingDisplay {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .disabled(clipExporter.isExporting || isSwitchingDisplay || availableDisplays.count <= 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// The display currently being recorded
    private var currentDisplayID: UInt32 {
        switch settings.displaySelectionMode {
        case .primary:
            // Primary is the largest display
            return availableDisplays.max(by: { $0.width * $0.height < $1.width * $1.height })?.id ?? 0
        case .specific:
            return settings.selectedDisplayID
        case .all:
            return 0 // Not applicable
        }
    }

    /// Label for the current display in the menu
    private var currentDisplayLabel: String {
        if availableDisplays.isEmpty {
            return "Loading..."
        }

        switch settings.displaySelectionMode {
        case .primary:
            if let display = availableDisplays.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                return "\(display.name) (Primary)"
            }
            return "Primary Display"
        case .specific:
            if let display = availableDisplays.first(where: { $0.id == settings.selectedDisplayID }) {
                return display.name
            }
            return "Display \(settings.selectedDisplayID)"
        case .all:
            return "All Displays"
        }
    }

    /// Handles display selection from the menu
    private func handleDisplaySelection(_ displayID: UInt32) {
        // Skip if already on this display
        guard displayID != currentDisplayID else { return }

        // Show confirmation dialog
        pendingDisplaySwitch = displayID
        showDisplaySwitchConfirmation = true
    }

    /// Performs the actual display switch after user confirmation
    private func performDisplaySwitch(to displayID: UInt32) {
        isSwitchingDisplay = true

        Task {
            do {
                try await recordingManager.switchDisplay(to: displayID)
                // Refresh display list in case anything changed
                availableDisplays = await recordingManager.getDisplayList()
            } catch {
                // Error is handled by RecordingManager and shown in status
            }
            isSwitchingDisplay = false
        }
    }

    @ViewBuilder
    private var diskSpaceIndicator: some View {
        // This is a placeholder - the actual disk space is checked by BufferManager
        // We show a warning icon if recording is active (disk space is monitored internally)
        EmptyView()
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .overlay(
                // Pulsing animation for recording state
                Circle()
                    .stroke(statusColor.opacity(0.5), lineWidth: 2)
                    .scaleEffect(recordingManager.isRecording && recordingManager.recordingError == nil ? 1.5 : 1.0)
                    .opacity(recordingManager.isRecording && recordingManager.recordingError == nil ? 0 : 1)
                    .animation(
                        recordingManager.isRecording && recordingManager.recordingError == nil
                            ? Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false)
                            : .default,
                        value: recordingManager.isRecording
                    )
            )
    }

    private var statusColor: Color {
        // Priority: Error > Recovery > Quality Degraded > Recording > Paused
        if recordingManager.recordingError != nil {
            return .orange
        }
        if recordingManager.isInRecoveryMode {
            return .yellow
        }
        if recordingManager.isQualityDegraded {
            return .yellow
        }
        return recordingManager.isRecording ? .red : .gray
    }

    private var statusText: String {
        if recordingManager.isInRecoveryMode {
            return "Recovering..."
        }
        if let _ = recordingManager.recordingError {
            return "Error"
        }
        if recordingManager.isQualityDegraded {
            return "Recording (Reduced Quality)"
        }
        return recordingManager.isRecording ? "Recording" : "Paused"
    }

    private func errorDescription(_ error: Error) -> String {
        if let recordingError = error as? RecordingError {
            switch recordingError {
            case .permissionDenied:
                return "Screen recording permission required"
            case .noDisplaysAvailable:
                return "No displays available"
            case .streamSetupFailed:
                return "Failed to start screen capture"
            case .writerSetupFailed:
                return "Failed to create video file"
            case .segmentFinalizationFailed:
                return "Failed to save video segment"
            case .maxRetriesExceeded:
                return "Multiple failures - will retry automatically"
            case .diskSpaceLow:
                return "Insufficient disk space"
            case .watchdogTimeout:
                return "Recording stalled - will retry automatically"
            }
        }
        return error.localizedDescription
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
                    .font(.headline)
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
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Max: \(formatDuration(min(recordingManager.bufferDuration, 900)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }

            // Save button
            Button(action: {
                Task {
                    do {
                        try await clipExporter.exportClip(duration: selectedDuration)
                    } catch {
                        // Error handling is done by ClipExporter
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
                        .font(.callout)
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption2)
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
        VStack(spacing: 2) {
            MenuItemButton(title: "Preferences...", shortcut: "⌘,") {
                onPreferences()
            }

            MenuItemButton(title: "Quit DevCam", shortcut: "⌘Q") {
                onQuit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Menu Item Button

/// A button styled like a native macOS menu item with hover state
struct MenuItemButton: View {
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.accentColor.opacity(0.8) : Color.clear)
            .foregroundColor(isHovered ? .white : .primary)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovering in
            isHovered = hovering
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
        settings: settings
    )

    MenuBarView(
        recordingManager: recordingManager,
        clipExporter: clipExporter,
        settings: settings,
        bufferManager: bufferManager,
        onPreferences: { },
        onQuit: { }
    )
}
