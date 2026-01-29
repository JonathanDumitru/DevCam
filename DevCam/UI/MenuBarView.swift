//
//  MenuBarView.swift
//  DevCam
//
//  Menubar dropdown menu with save actions and settings
//

import SwiftUI
import CoreMedia

struct MenuBarView: View {
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var clipExporter: ClipExporter
    let bufferManager: BufferManager
    @ObservedObject var windowCaptureManager: WindowCaptureManager
    let settings: AppSettings
    let onSelectWindows: () -> Void

    let onPreferences: () -> Void
    let onQuit: () -> Void

    @State private var selectedDuration: Double = 300 // Default 5 minutes (in seconds)
    @State private var showAdvancedWindow = false
    @State private var isPreparingPreview = false

    var body: some View {
        VStack(spacing: 0) {
            // Status section
            statusSection

            Divider()

            // Capture mode
            captureModeSection

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
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 4) {
            // Primary status row
            HStack {
                statusIndicator
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }

            // Secondary status indicators
            if recordingManager.isInRecoveryMode {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("Auto-recovery in progress...")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Spacer()
                }
            }

            if recordingManager.isQualityDegraded {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text("Quality reduced due to system constraints")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // Buffer status
            if recordingManager.isRecording {
                HStack {
                    Text(bufferStatusText)
                        .font(.system(size: 11))
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
                            .font(.system(size: 11))
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
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Capture Mode Section

    private var captureModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture Mode")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)

            VStack(spacing: 4) {
                // Display option
                Button(action: {
                    settings.captureMode = .display
                }) {
                    HStack {
                        Image(systemName: settings.captureMode == .display ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(settings.captureMode == .display ? .accentColor : .secondary)
                        Text("Display")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                // Windows option
                Button(action: {
                    settings.captureMode = .windows
                }) {
                    HStack {
                        Image(systemName: settings.captureMode == .windows ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(settings.captureMode == .windows ? .accentColor : .secondary)
                        Text("Windows")
                        if !windowCaptureManager.selectedWindows.isEmpty {
                            Text("(\(windowCaptureManager.selectedWindows.count))")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // Select Windows button (when in windows mode)
            if settings.captureMode == .windows {
                Button(action: {
                    onSelectWindows()
                }) {
                    HStack {
                        Text("Select Windows...")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\u{2318}\u{21E7}W")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                // Warning for high window count
                if windowCaptureManager.selectedWindows.count > settings.windowCountWarningThreshold {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                        Text("\(windowCaptureManager.selectedWindows.count) windows - quality may degrade")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .padding(.vertical, 4)
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

            // Preview button
            Button(action: {
                Task {
                    await openPreviewWindow()
                }
            }) {
                HStack {
                    Text("Preview & Trim...")
                        .font(.system(size: 12))
                    Spacer()
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .disabled(!canSave() || isPreparingPreview)
            .opacity((canSave() && !isPreparingPreview) ? 1.0 : 0.5)

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

    private func openPreviewWindow() async {
        isPreparingPreview = true
        defer { isPreparingPreview = false }

        do {
            guard let previewURL = try await clipExporter.preparePreview(duration: selectedDuration) else {
                return
            }

            await MainActor.run {
                PreviewWindow.show(videoURL: previewURL) { timeRange in
                    Task {
                        try await clipExporter.exportClipWithRange(timeRange, from: previewURL)
                        // Clean up temp file after export
                        try? FileManager.default.removeItem(at: previewURL)
                    }
                }
            }
        } catch {
            // Error handling - ClipExporter will have set exportError
        }
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
        settings: settings
    )
    let windowCaptureManager = WindowCaptureManager(settings: settings)

    MenuBarView(
        recordingManager: recordingManager,
        clipExporter: clipExporter,
        bufferManager: bufferManager,
        windowCaptureManager: windowCaptureManager,
        settings: settings,
        onSelectWindows: { },
        onPreferences: { },
        onQuit: { }
    )
}
