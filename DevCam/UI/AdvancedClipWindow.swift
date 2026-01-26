//
//  AdvancedClipWindow.swift
//  DevCam
//
//  Advanced clip export with timeline and precise start/end selection
//

import SwiftUI

struct AdvancedClipWindow: View {
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var clipExporter: ClipExporter
    @Environment(\.dismiss) var dismiss

    @State private var startOffset: Double = 0 // Seconds from current time
    @State private var endOffset: Double = 300 // Seconds from current time (5 min default)
    @State private var isExporting = false

    var maxDuration: Double {
        min(recordingManager.bufferDuration, 900) // Max 15 minutes
    }

    var clipDuration: Double {
        endOffset - startOffset
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Advanced Clip Export")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // Timeline visualization
            timelineView

            // Start time selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.headline)

                HStack {
                    Slider(value: $startOffset, in: 0...maxDuration, step: 1)
                        .onChange(of: startOffset) { newValue in
                            // Ensure end is always after start
                            if endOffset <= newValue {
                                endOffset = min(newValue + 60, maxDuration)
                            }
                        }

                    Text(formatTimeAgo(startOffset))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
            }
            .padding(.horizontal)

            // End time selector
            VStack(alignment: .leading, spacing: 8) {
                Text("End Time")
                    .font(.headline)

                HStack {
                    Slider(value: $endOffset, in: 0...maxDuration, step: 1)
                        .onChange(of: endOffset) { newValue in
                            // Ensure start is always before end
                            if startOffset >= newValue {
                                startOffset = max(newValue - 60, 0)
                            }
                        }

                    Text(formatTimeAgo(endOffset))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
            }
            .padding(.horizontal)

            // Clip info
            VStack(spacing: 8) {
                HStack {
                    Text("Clip Duration:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDuration(clipDuration))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                }

                HStack {
                    Text("Available Buffer:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDuration(maxDuration))
                        .font(.system(size: 14, design: .monospaced))
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            Spacer()

            // Export button
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: exportClip) {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                        Text("Exporting...")
                    } else {
                        Text("Export Clip")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(clipDuration < 1 || isExporting)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)
                .padding(.horizontal)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 40)

                    // Buffer duration track
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: geometry.size.width * (maxDuration / 900), height: 40)

                    // Selected range
                    Rectangle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(
                            width: geometry.size.width * (clipDuration / 900),
                            height: 40
                        )
                        .offset(x: geometry.size.width * (startOffset / 900))

                    // Start marker
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 3, height: 40)
                        .offset(x: geometry.size.width * (startOffset / 900))

                    // End marker
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 3, height: 40)
                        .offset(x: geometry.size.width * (endOffset / 900))

                    // Time labels
                    HStack {
                        Text("Now")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("-15:00")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
                .cornerRadius(4)
            }
            .frame(height: 40)
            .padding(.horizontal)

            // Legend
            HStack(spacing: 16) {
                Label("Start", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))

                Label("End", systemImage: "circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 11))

                Label("Selected", systemImage: "rectangle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 11))
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func exportClip() {
        isExporting = true

        Task {
            do {
                print("💾 DEBUG: Advanced export - duration: \(clipDuration)s, start: \(startOffset)s, end: \(endOffset)s")
                // For now, export the clip duration (we'll add start offset support later)
                try await clipExporter.exportClip(duration: clipDuration)
                print("✅ DEBUG: Advanced export completed successfully")

                await MainActor.run {
                    isExporting = false
                    dismiss()
                }
            } catch {
                print("❌ DEBUG: Advanced export failed: \(error)")
                await MainActor.run {
                    isExporting = false
                }
            }
        }
    }

    // MARK: - Formatting

    private func formatTimeAgo(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "-%d:%02d", minutes, secs)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
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

    AdvancedClipWindow(
        recordingManager: recordingManager,
        clipExporter: clipExporter
    )
}
