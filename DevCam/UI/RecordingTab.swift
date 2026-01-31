//
//  RecordingTab.swift
//  DevCam
//
//  Recording preferences: display selection, audio capture, battery mode
//

import SwiftUI

struct RecordingTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var recordingManager: RecordingManager

    @State private var availableDisplays: [(id: UInt32, name: String, width: Int, height: Int)] = []
    @State private var isLoadingDisplays = true

    // Display switch confirmation state
    @State private var showDisplaySwitchConfirmation = false
    @State private var pendingDisplaySwitch: UInt32?
    @State private var isSwitchingDisplay = false

    var body: some View {
        Form {
            // Display Selection
            displaySelectionSection

            // Frame Rate
            frameRateSection

            // Audio Capture
            audioCaptureSection

            // Adaptive Quality
            adaptiveQualitySection

            // Battery Mode
            batteryModeSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadDisplays()
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
    }

    // MARK: - Display Selection Section

    private var displaySelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Display")
                    .font(.headline)

                Picker("Record from", selection: $settings.displaySelectionMode) {
                    ForEach(DisplaySelectionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(settings.displaySelectionMode.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // Show display picker when specific mode is selected
                if settings.displaySelectionMode == .specific {
                    Divider()

                    if isLoadingDisplays {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Detecting displays...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if availableDisplays.isEmpty {
                        Label("No displays detected", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        HStack {
                            Text("Select Display")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if isSwitchingDisplay {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Switching...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        ForEach(availableDisplays, id: \.id) { display in
                            displayRow(display)
                                .disabled(isSwitchingDisplay)
                        }
                    }

                    Button("Refresh Displays") {
                        Task { await loadDisplays() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // Warning for "all displays" mode
                if settings.displaySelectionMode == .all {
                    Label("All displays mode is not yet implemented", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private func displayRow(_ display: (id: UInt32, name: String, width: Int, height: Int)) -> some View {
        HStack {
            Button(action: {
                handleDisplaySelection(display.id)
            }) {
                HStack {
                    Image(systemName: settings.selectedDisplayID == display.id ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(settings.selectedDisplayID == display.id ? .blue : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(display.name)
                            .font(.system(size: 13))

                        Text("\(display.width) x \(display.height)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isPrimaryDisplay(display) {
                        Text("Primary")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func isPrimaryDisplay(_ display: (id: UInt32, name: String, width: Int, height: Int)) -> Bool {
        // Primary is the largest display
        guard let largest = availableDisplays.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
            return false
        }
        return display.id == largest.id
    }

    // MARK: - Frame Rate Section

    private var frameRateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Frame Rate")
                    .font(.headline)

                Picker("Target frame rate", selection: $settings.targetFrameRate) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }
                .pickerStyle(.segmented)

                Text("Lower frame rates reduce CPU usage. 30 fps is recommended for most use cases.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Divider()

                Toggle("Adaptive frame rate", isOn: $settings.adaptiveFrameRateEnabled)

                if settings.adaptiveFrameRateEnabled {
                    Text("Automatically reduces frame rate when no mouse or keyboard activity is detected.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Idle after:")
                            .font(.caption)

                        Picker("", selection: $settings.idleThreshold) {
                            Text("3s").tag(3.0)
                            Text("5s").tag(5.0)
                            Text("10s").tag(10.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }

                    HStack {
                        Text("Idle frame rate:")
                            .font(.caption)

                        Picker("", selection: $settings.idleFrameRate) {
                            ForEach(FrameRate.allCases.filter { $0.rawValue < settings.targetFrameRate.rawValue }) { rate in
                                Text(rate.displayName).tag(rate)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }

                    Label("Requires Accessibility permission for input monitoring", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Audio Capture Section

    private var audioCaptureSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Audio")
                    .font(.headline)

                Picker("Capture", selection: $settings.audioCaptureMode) {
                    ForEach(AudioCaptureMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(settings.audioCaptureMode.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if settings.audioCaptureMode.capturesSystemAudio {
                    Label("System audio requires additional permissions", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if settings.audioCaptureMode.capturesMicrophone {
                    Label("Microphone access will be requested when recording starts", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Adaptive Quality Section

    private var adaptiveQualitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Adaptive Quality")
                    .font(.headline)

                Toggle("Automatically adjust quality based on system load", isOn: $settings.adaptiveQualityEnabled)
                    .onChange(of: settings.adaptiveQualityEnabled) { _ in
                        recordingManager.updateAdaptiveQualityMonitoring()
                    }

                if settings.adaptiveQualityEnabled {
                    Text("When CPU usage is high, recording quality will be temporarily reduced to maintain smooth capture.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Divider()

                    HStack {
                        Text("Reduce quality when CPU above:")
                            .font(.caption)

                        Picker("", selection: $settings.cpuThresholdHigh) {
                            Text("70%").tag(70)
                            Text("80%").tag(80)
                            Text("90%").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    HStack {
                        Text("Restore quality when CPU below:")
                            .font(.caption)

                        Picker("", selection: $settings.cpuThresholdLow) {
                            Text("40%").tag(40)
                            Text("50%").tag(50)
                            Text("60%").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }
            }
        }
    }

    // MARK: - Battery Mode Section

    private var batteryModeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Battery")
                    .font(.headline)

                Picker("When on battery", selection: $settings.batteryMode) {
                    ForEach(BatteryMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(settings.batteryMode.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if settings.batteryMode == .pauseOnLow {
                    HStack {
                        Text("Low battery threshold:")
                            .font(.caption)

                        Picker("", selection: $settings.lowBatteryThreshold) {
                            Text("10%").tag(10)
                            Text("20%").tag(20)
                            Text("30%").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadDisplays() async {
        isLoadingDisplays = true
        availableDisplays = await recordingManager.getDisplayList()
        isLoadingDisplays = false

        // Auto-select first display if none selected
        if settings.selectedDisplayID == 0, let first = availableDisplays.first {
            settings.selectedDisplayID = first.id
        }
    }

    /// Handles display selection - shows confirmation if recording is active
    private func handleDisplaySelection(_ displayID: UInt32) {
        // Skip if already selected
        guard displayID != settings.selectedDisplayID else { return }

        // If recording is active, show confirmation dialog
        if recordingManager.isRecording {
            pendingDisplaySwitch = displayID
            showDisplaySwitchConfirmation = true
        } else {
            // Not recording - just update settings directly
            settings.selectedDisplayID = displayID
        }
    }

    /// Performs the actual display switch after user confirmation
    private func performDisplaySwitch(to displayID: UInt32) {
        isSwitchingDisplay = true

        Task {
            do {
                try await recordingManager.switchDisplay(to: displayID)
                // Refresh display list in case anything changed
                await loadDisplays()
            } catch {
                // Error is handled by RecordingManager
            }
            isSwitchingDisplay = false
        }
    }
}

// MARK: - Preview

#Preview {
    let settings = AppSettings()
    let bufferManager = BufferManager()
    let permissionManager = PermissionManager()
    let recordingManager = RecordingManager(
        bufferManager: bufferManager,
        permissionManager: permissionManager,
        settings: settings
    )

    return RecordingTab(settings: settings, recordingManager: recordingManager)
        .frame(width: 500, height: 500)
}
