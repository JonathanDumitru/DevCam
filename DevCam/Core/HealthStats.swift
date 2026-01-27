//
//  HealthStats.swift
//  DevCam
//
//  Tracks application health statistics for monitoring and debugging.
//

import Foundation
import Combine
import OSLog

/// Tracks application health statistics for the Health Dashboard.
/// Persists key metrics to UserDefaults for cross-session tracking.
@MainActor
class HealthStats: ObservableObject {

    // MARK: - Published Statistics

    /// Total app uptime since launch (in seconds)
    @Published private(set) var currentSessionUptime: TimeInterval = 0

    /// Total recording time this session (in seconds)
    @Published private(set) var currentSessionRecordingTime: TimeInterval = 0

    /// Number of errors encountered this session
    @Published private(set) var currentSessionErrors: Int = 0

    /// Number of successful auto-recoveries this session
    @Published private(set) var currentSessionRecoveries: Int = 0

    /// Number of clips exported this session
    @Published private(set) var currentSessionExports: Int = 0

    /// Current disk space usage by buffer (in bytes)
    @Published private(set) var bufferDiskUsage: Int64 = 0

    /// Available disk space (in bytes)
    @Published private(set) var availableDiskSpace: Int64 = 0

    /// Total segments in buffer
    @Published private(set) var segmentCount: Int = 0

    /// Last error message (if any)
    @Published private(set) var lastErrorMessage: String?

    /// Last error timestamp
    @Published private(set) var lastErrorTime: Date?

    // MARK: - Persisted Statistics (across sessions)

    @Published private(set) var totalLifetimeRecordingHours: Double = 0
    @Published private(set) var totalLifetimeExports: Int = 0
    @Published private(set) var totalLifetimeErrors: Int = 0
    @Published private(set) var totalLifetimeRecoveries: Int = 0

    // MARK: - Error Log

    /// Recent errors for display (max 50)
    @Published private(set) var recentErrors: [ErrorLogEntry] = []

    struct ErrorLogEntry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let category: String
        let message: String
        let wasRecovered: Bool

        init(timestamp: Date, category: String, message: String, wasRecovered: Bool = false) {
            self.id = UUID()
            self.timestamp = timestamp
            self.category = category
            self.message = message
            self.wasRecovered = wasRecovered
        }
    }

    // MARK: - Dependencies

    private let bufferManager: BufferManager
    private var recordingManager: RecordingManager?

    // MARK: - Timers

    private var uptimeTimer: Timer?
    private var diskCheckTimer: Timer?
    private let launchTime = Date()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let totalRecordingHours = "HealthStats.totalRecordingHours"
        static let totalExports = "HealthStats.totalExports"
        static let totalErrors = "HealthStats.totalErrors"
        static let totalRecoveries = "HealthStats.totalRecoveries"
        static let recentErrors = "HealthStats.recentErrors"
    }

    // MARK: - Initialization

    init(bufferManager: BufferManager) {
        self.bufferManager = bufferManager
        loadPersistedStats()
        startTimers()
        updateDiskStats()
    }

    /// Sets the recording manager for observing recording time.
    /// Called after initialization since RecordingManager may be created later.
    func setRecordingManager(_ manager: RecordingManager) {
        self.recordingManager = manager
    }

    deinit {
        uptimeTimer?.invalidate()
        diskCheckTimer?.invalidate()
    }

    // MARK: - Timer Management

    private func startTimers() {
        // Update uptime every second
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateUptime()
            }
        }

        // Update disk stats every 30 seconds
        diskCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDiskStats()
            }
        }
    }

    private func updateUptime() {
        currentSessionUptime = Date().timeIntervalSince(launchTime)

        // Track recording time
        if recordingManager?.isRecording == true {
            currentSessionRecordingTime += 1.0
        }
    }

    private func updateDiskStats() {
        // Get buffer disk usage
        let bufferDir = bufferManager.getBufferDirectory()
        bufferDiskUsage = calculateDirectorySize(bufferDir)

        // Get available disk space
        let diskCheck = bufferManager.checkDiskSpace()
        availableDiskSpace = diskCheck.availableBytes

        // Get segment count
        segmentCount = bufferManager.getSegmentCount()
    }

    private func calculateDirectorySize(_ url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = attributes.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        return totalSize
    }

    // MARK: - Event Recording

    /// Records an error occurrence.
    func recordError(category: String, message: String, wasRecovered: Bool = false) {
        currentSessionErrors += 1
        totalLifetimeErrors += 1
        lastErrorMessage = message
        lastErrorTime = Date()

        let entry = ErrorLogEntry(
            timestamp: Date(),
            category: category,
            message: message,
            wasRecovered: wasRecovered
        )

        recentErrors.insert(entry, at: 0)
        if recentErrors.count > 50 {
            recentErrors.removeLast()
        }

        savePersistedStats()
        DevCamLogger.app.debug("Health stats: recorded error - \(category): \(message)")
    }

    /// Records a successful recovery.
    func recordRecovery() {
        currentSessionRecoveries += 1
        totalLifetimeRecoveries += 1

        // Mark the last error as recovered
        if !recentErrors.isEmpty {
            var lastError = recentErrors[0]
            recentErrors[0] = ErrorLogEntry(
                timestamp: lastError.timestamp,
                category: lastError.category,
                message: lastError.message,
                wasRecovered: true
            )
        }

        savePersistedStats()
        DevCamLogger.app.debug("Health stats: recorded recovery")
    }

    /// Records a successful export.
    func recordExport() {
        currentSessionExports += 1
        totalLifetimeExports += 1
        savePersistedStats()
        DevCamLogger.app.debug("Health stats: recorded export")
    }

    /// Updates recording time at the end of a session.
    func finalizeSession() {
        let hoursRecorded = currentSessionRecordingTime / 3600.0
        totalLifetimeRecordingHours += hoursRecorded
        savePersistedStats()
    }

    // MARK: - Persistence

    private func loadPersistedStats() {
        let defaults = UserDefaults.standard
        totalLifetimeRecordingHours = defaults.double(forKey: Keys.totalRecordingHours)
        totalLifetimeExports = defaults.integer(forKey: Keys.totalExports)
        totalLifetimeErrors = defaults.integer(forKey: Keys.totalErrors)
        totalLifetimeRecoveries = defaults.integer(forKey: Keys.totalRecoveries)

        // Load recent errors
        if let data = defaults.data(forKey: Keys.recentErrors),
           let errors = try? JSONDecoder().decode([ErrorLogEntry].self, from: data) {
            recentErrors = errors
        }
    }

    private func savePersistedStats() {
        let defaults = UserDefaults.standard
        defaults.set(totalLifetimeRecordingHours, forKey: Keys.totalRecordingHours)
        defaults.set(totalLifetimeExports, forKey: Keys.totalExports)
        defaults.set(totalLifetimeErrors, forKey: Keys.totalErrors)
        defaults.set(totalLifetimeRecoveries, forKey: Keys.totalRecoveries)

        // Save recent errors
        if let data = try? JSONEncoder().encode(recentErrors) {
            defaults.set(data, forKey: Keys.recentErrors)
        }
    }

    // MARK: - Formatted Output

    var formattedUptime: String {
        formatDuration(currentSessionUptime)
    }

    var formattedRecordingTime: String {
        formatDuration(currentSessionRecordingTime)
    }

    var formattedBufferUsage: String {
        ByteCountFormatter.string(fromByteCount: bufferDiskUsage, countStyle: .file)
    }

    var formattedAvailableSpace: String {
        ByteCountFormatter.string(fromByteCount: availableDiskSpace, countStyle: .file)
    }

    var formattedLifetimeRecording: String {
        if totalLifetimeRecordingHours < 1 {
            let minutes = Int(totalLifetimeRecordingHours * 60)
            return "\(minutes) minutes"
        }
        return String(format: "%.1f hours", totalLifetimeRecordingHours)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    // MARK: - Export Error Log

    /// Generates a text report of recent errors for sharing.
    func generateErrorReport() -> String {
        var report = """
        DevCam Health Report
        Generated: \(Date().formatted())

        === Session Statistics ===
        Uptime: \(formattedUptime)
        Recording Time: \(formattedRecordingTime)
        Errors: \(currentSessionErrors)
        Recoveries: \(currentSessionRecoveries)
        Exports: \(currentSessionExports)

        === Disk Usage ===
        Buffer Size: \(formattedBufferUsage)
        Available Space: \(formattedAvailableSpace)
        Segments: \(segmentCount)

        === Lifetime Statistics ===
        Total Recording: \(formattedLifetimeRecording)
        Total Exports: \(totalLifetimeExports)
        Total Errors: \(totalLifetimeErrors)
        Total Recoveries: \(totalLifetimeRecoveries)

        === Recent Errors ===

        """

        if recentErrors.isEmpty {
            report += "No errors recorded.\n"
        } else {
            for error in recentErrors.prefix(20) {
                let recoveredStatus = error.wasRecovered ? " [RECOVERED]" : ""
                report += "[\(error.timestamp.formatted())] [\(error.category)]\(recoveredStatus)\n"
                report += "  \(error.message)\n\n"
            }
        }

        return report
    }
}
