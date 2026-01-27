//
//  AdvancedClipWindow.swift
//  DevCam
//
//  Advanced clip export with timeline, precise start/end selection, preview, and annotations
//

import SwiftUI

struct AdvancedClipWindow: View {
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var clipExporter: ClipExporter
    let bufferManager: BufferManager
    @Environment(\.dismiss) var dismiss

    // Timeline state
    @State private var startOffset: Double = 0 // Seconds from current time
    @State private var endOffset: Double = 300 // Seconds from current time (5 min default)
    @State private var isExporting = false

    // Custom duration input
    @State private var customMinutes: String = "5"
    @State private var customSeconds: String = "00"
    @State private var useCustomDuration: Bool = false

    // Preview (Phase 3)
    @State private var showPreview: Bool = false
    @State private var previewSegments: [SegmentInfo] = []

    // Annotations (Phase 3)
    @State private var clipTitle: String = ""
    @State private var clipNotes: String = ""
    @State private var clipTags: String = ""
    @State private var showAnnotations: Bool = false

    var maxDuration: Double {
        min(recordingManager.bufferDuration, 900) // Max 15 minutes
    }

    var clipDuration: Double {
        if useCustomDuration {
            let mins = Double(customMinutes) ?? 0
            let secs = Double(customSeconds) ?? 0
            return min(mins * 60 + secs, maxDuration)
        }
        return endOffset - startOffset
    }

    var estimatedFileSize: String {
        // Rough estimate: ~5MB per minute at high quality
        let mbPerMinute = 5.0
        let estimatedMB = (clipDuration / 60.0) * mbPerMinute
        if estimatedMB < 1 {
            return String(format: "~%.0f KB", estimatedMB * 1024)
        }
        return String(format: "~%.1f MB", estimatedMB)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Duration mode selector
                    durationModeSelector

                    if useCustomDuration {
                        // Custom duration input
                        customDurationSection
                    } else {
                        // Timeline visualization
                        timelineView

                        // Start/End time selectors
                        trimControlsSection
                    }

                    Divider()

                    // Clip info summary
                    clipInfoSection

                    Divider()

                    // Preview section (collapsible)
                    previewSection

                    Divider()

                    // Annotations section (collapsible)
                    annotationsSection
                }
                .padding(.horizontal)
            }

            Spacer()

            // Export button
            exportButtonSection
        }
        .frame(width: 520, height: 680)
    }

    // MARK: - Header Section

    private var headerSection: some View {
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
    }

    // MARK: - Duration Mode Selector

    private var durationModeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration Mode")
                .font(.headline)

            Picker("", selection: $useCustomDuration) {
                Text("Timeline Trim").tag(false)
                Text("Custom Duration").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Custom Duration Section

    private var customDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clip Duration")
                .font(.headline)

            // Quick presets
            HStack(spacing: 8) {
                ForEach([1, 2, 5, 10, 15], id: \.self) { minutes in
                    Button("\(minutes) min") {
                        customMinutes = "\(minutes)"
                        customSeconds = "00"
                    }
                    .buttonStyle(.bordered)
                    .disabled(Double(minutes * 60) > maxDuration)
                }
            }

            // Manual input
            HStack(spacing: 4) {
                Text("Or enter:")
                    .foregroundColor(.secondary)

                TextField("", text: $customMinutes)
                    .frame(width: 40)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .onChange(of: customMinutes) { newValue in
                        // Validate: only digits, max 2 chars
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue || filtered.count > 2 {
                            customMinutes = String(filtered.prefix(2))
                        }
                    }

                Text(":")
                    .font(.system(size: 16, weight: .medium))

                TextField("", text: $customSeconds)
                    .frame(width: 40)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .onChange(of: customSeconds) { newValue in
                        // Validate: only digits, max 2 chars, max 59
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue || filtered.count > 2 {
                            customSeconds = String(filtered.prefix(2))
                        }
                        if let val = Int(customSeconds), val > 59 {
                            customSeconds = "59"
                        }
                    }

                Text("(min:sec)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Max: \(formatDuration(maxDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Duration warning if exceeds buffer
            if clipDuration > maxDuration {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Duration exceeds available buffer. Will use maximum available.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 50)

                    // Buffer duration track
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: geometry.size.width * (maxDuration / 900), height: 50)

                    // Selected range
                    Rectangle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(
                            width: geometry.size.width * (clipDuration / 900),
                            height: 50
                        )
                        .offset(x: geometry.size.width * (startOffset / 900))

                    // Start marker (draggable appearance)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: 6, height: 50)
                        .offset(x: geometry.size.width * (startOffset / 900) - 3)
                        .shadow(radius: 2)

                    // End marker (draggable appearance)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 6, height: 50)
                        .offset(x: geometry.size.width * (endOffset / 900) - 3)
                        .shadow(radius: 2)

                    // Time markers
                    ForEach([0, 5, 10, 15], id: \.self) { minute in
                        let offset = geometry.size.width * (Double(minute * 60) / 900)
                        VStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 1, height: 10)
                            Spacer()
                        }
                        .frame(height: 50)
                        .offset(x: offset)
                    }

                    // Time labels
                    VStack {
                        Spacer()
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
                    .frame(height: 65)
                }
                .cornerRadius(6)
            }
            .frame(height: 65)

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

                Spacer()

                Text("Drag sliders below to adjust")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Trim Controls Section

    private var trimControlsSection: some View {
        VStack(spacing: 12) {
            // Start time selector
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Start")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatTimeAgo(startOffset))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.green)
                }

                Slider(value: $startOffset, in: 0...maxDuration, step: 1)
                    .tint(.green)
                    .onChange(of: startOffset) { newValue in
                        // Ensure end is always after start (min 1 second gap)
                        if endOffset <= newValue {
                            endOffset = min(newValue + 60, maxDuration)
                        }
                    }
            }

            // End time selector
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("End")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatTimeAgo(endOffset))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.red)
                }

                Slider(value: $endOffset, in: 0...maxDuration, step: 1)
                    .tint(.red)
                    .onChange(of: endOffset) { newValue in
                        // Ensure start is always before end
                        if startOffset >= newValue {
                            startOffset = max(newValue - 60, 0)
                        }
                    }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Clip Info Section

    private var clipInfoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Clip Summary")
                    .font(.headline)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Duration", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(min(clipDuration, maxDuration)))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Label("Est. Size", systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(estimatedFileSize)
                        .font(.system(size: 16, weight: .medium))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Label("Available", systemImage: "cylinder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(maxDuration))
                        .font(.system(size: 16, design: .monospaced))
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    showPreview.toggle()
                    if showPreview {
                        loadPreviewSegments()
                    }
                }
            }) {
                HStack {
                    Text("Preview")
                        .font(.headline)

                    if !previewSegments.isEmpty && showPreview {
                        Text("(\(formatDuration(min(clipDuration, maxDuration))))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: showPreview ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showPreview {
                VStack(alignment: .leading, spacing: 8) {
                    if maxDuration < 1 {
                        // No buffer content
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "film.slash")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Text("No recording available to preview")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .frame(height: 120)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    } else {
                        VideoPreviewView(segments: previewSegments)

                        // Refresh preview button
                        HStack {
                            Spacer()
                            Button(action: loadPreviewSegments) {
                                Label("Refresh Preview", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Annotations Section

    private var annotationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { showAnnotations.toggle() } }) {
                HStack {
                    Text("Annotations")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showAnnotations ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showAnnotations {
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Bug fix for login issue", text: $clipTitle)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $clipNotes)
                            .frame(height: 60)
                            .font(.system(size: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (comma-separated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., bugfix, auth, sprint-12", text: $clipTags)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Export Button Section

    private var exportButtonSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if isExporting {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }

            Button(action: exportClip) {
                Text(isExporting ? "Exporting..." : "Export Clip")
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(clipDuration < 1 || isExporting || maxDuration < 1)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadPreviewSegments() {
        let duration = min(clipDuration, maxDuration)
        previewSegments = bufferManager.getSegmentsForTimeRange(duration: duration)
    }

    private func exportClip() {
        isExporting = true

        // Parse tags
        let tags = clipTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Prepare annotation data
        let title = clipTitle.isEmpty ? nil : clipTitle
        let notes = clipNotes.isEmpty ? nil : clipNotes

        Task {
            do {
                try await clipExporter.exportClip(
                    duration: min(clipDuration, maxDuration),
                    title: title,
                    notes: notes,
                    tags: tags
                )

                await MainActor.run {
                    isExporting = false
                    dismiss()
                }
            } catch {
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
        return String(format: "-%d:%02d ago", minutes, secs)
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
        settings: settings
    )

    AdvancedClipWindow(
        recordingManager: recordingManager,
        clipExporter: clipExporter,
        bufferManager: bufferManager
    )
}
