//
//  HealthTab.swift
//  DevCam
//
//  Health dashboard showing app statistics, disk usage, and error log.
//

import SwiftUI
import UniformTypeIdentifiers

struct HealthTab: View {
    @ObservedObject var healthStats: HealthStats
    @ObservedObject var recordingManager: RecordingManager

    @State private var showingExportSheet = false
    @State private var exportedReport: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Current Status
                currentStatusSection

                Divider()

                // Session Statistics
                sessionStatsSection

                Divider()

                // Disk Usage
                diskUsageSection

                Divider()

                // Lifetime Statistics
                lifetimeStatsSection

                Divider()

                // Recent Errors
                recentErrorsSection

                // Export Button
                exportSection
            }
            .padding()
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportReportSheet(report: exportedReport) {
                showingExportSheet = false
            }
        }
    }

    // MARK: - Current Status Section

    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Status")
                .font(.headline)

            HStack(spacing: 16) {
                StatusBadge(
                    title: "Recording",
                    value: recordingManager.isRecording ? "Active" : "Paused",
                    color: recordingManager.isRecording ? .green : .gray
                )

                if recordingManager.isInRecoveryMode {
                    StatusBadge(
                        title: "Recovery",
                        value: "In Progress",
                        color: .orange
                    )
                }

                if recordingManager.isQualityDegraded {
                    StatusBadge(
                        title: "Quality",
                        value: "Reduced",
                        color: .yellow
                    )
                }

                if recordingManager.recordingError != nil {
                    StatusBadge(
                        title: "Error",
                        value: "Active",
                        color: .red
                    )
                }
            }
        }
    }

    // MARK: - Session Statistics Section

    private var sessionStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Statistics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Uptime", value: healthStats.formattedUptime, icon: "clock")
                StatCard(title: "Recording", value: healthStats.formattedRecordingTime, icon: "record.circle")
                StatCard(title: "Exports", value: "\(healthStats.currentSessionExports)", icon: "square.and.arrow.up")
                StatCard(title: "Errors", value: "\(healthStats.currentSessionErrors)", icon: "exclamationmark.triangle", valueColor: healthStats.currentSessionErrors > 0 ? .orange : .primary)
                StatCard(title: "Recoveries", value: "\(healthStats.currentSessionRecoveries)", icon: "arrow.clockwise", valueColor: healthStats.currentSessionRecoveries > 0 ? .green : .primary)
                StatCard(title: "Segments", value: "\(healthStats.segmentCount)", icon: "film.stack")
            }
        }
    }

    // MARK: - Disk Usage Section

    private var diskUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Disk Usage")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Buffer Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(healthStats.formattedBufferUsage)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Space")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(healthStats.formattedAvailableSpace)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(diskSpaceColor)
                }

                Spacer()
            }

            // Disk space warning
            if healthStats.availableDiskSpace < 1_000_000_000 { // Less than 1 GB
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Low disk space may affect recording")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private var diskSpaceColor: Color {
        if healthStats.availableDiskSpace < 500_000_000 { // Less than 500 MB
            return .red
        } else if healthStats.availableDiskSpace < 1_000_000_000 { // Less than 1 GB
            return .orange
        }
        return .primary
    }

    // MARK: - Lifetime Statistics Section

    private var lifetimeStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lifetime Statistics")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(healthStats.formattedLifetimeRecording)
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Exports")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(healthStats.totalLifetimeExports)")
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Errors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(healthStats.totalLifetimeErrors)")
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Recoveries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(healthStats.totalLifetimeRecoveries)")
                        .font(.body)
                }

                Spacer()
            }
        }
    }

    // MARK: - Recent Errors Section

    private var recentErrorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Errors")
                    .font(.headline)
                Spacer()
                if !healthStats.recentErrors.isEmpty {
                    Text("\(healthStats.recentErrors.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if healthStats.recentErrors.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No errors recorded")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(healthStats.recentErrors.prefix(5)) { error in
                        ErrorLogRow(error: error)
                    }

                    if healthStats.recentErrors.count > 5 {
                        Text("+ \(healthStats.recentErrors.count - 5) more errors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        HStack {
            Spacer()
            Button(action: exportReport) {
                Label("Export Health Report", systemImage: "square.and.arrow.up")
            }
        }
        .padding(.top, 8)
    }

    private func exportReport() {
        exportedReport = healthStats.generateErrorReport()
        showingExportSheet = true
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

struct ErrorLogRow: View {
    let error: HealthStats.ErrorLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: error.wasRecovered ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(error.wasRecovered ? .green : .orange)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(error.category)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(error.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExportReportSheet: View {
    let report: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Health Report")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    onDismiss()
                }
            }

            ScrollView {
                Text(report)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            HStack {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                }

                Button("Save to File...") {
                    saveReportToFile()
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }

    private func saveReportToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "DevCam_Health_Report_\(Date().formatted(.dateTime.year().month().day())).txt"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Preview

#Preview {
    let bufferManager = BufferManager()
    let healthStats = HealthStats(bufferManager: bufferManager)
    let permissionManager = PermissionManager()
    let settings = AppSettings()
    let recordingManager = RecordingManager(
        bufferManager: bufferManager,
        permissionManager: permissionManager,
        settings: settings
    )

    return HealthTab(healthStats: healthStats, recordingManager: recordingManager)
        .frame(width: 480, height: 500)
}
