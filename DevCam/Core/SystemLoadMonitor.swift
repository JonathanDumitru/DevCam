//
//  SystemLoadMonitor.swift
//  DevCam
//
//  Monitors system CPU load for adaptive quality recording
//

import Foundation
import Combine

/// System load information
struct SystemLoad {
    let cpuUsage: Double  // 0.0 - 1.0 (percentage as decimal)
    let isHighLoad: Bool

    static let unknown = SystemLoad(cpuUsage: 0, isHighLoad: false)

    var cpuPercentage: Int {
        Int(cpuUsage * 100)
    }
}

/// Monitors system CPU usage for adaptive quality control
@MainActor
class SystemLoadMonitor: ObservableObject {
    static let shared = SystemLoadMonitor()

    @Published private(set) var systemLoad: SystemLoad = .unknown
    @Published private(set) var isHighLoad: Bool = false

    private var monitorTimer: Timer?
    private let checkInterval: TimeInterval = 5.0 // Check every 5 seconds

    private var highThreshold: Double = 0.80 // 80%
    private var lowThreshold: Double = 0.50  // 50%

    // Moving average for smoothing
    private var cpuReadings: [Double] = []
    private let averageWindow = 6 // ~30 seconds of readings

    init() {}

    /// Starts monitoring system load
    func startMonitoring(highThreshold: Int = 80, lowThreshold: Int = 50) {
        self.highThreshold = Double(highThreshold) / 100.0
        self.lowThreshold = Double(lowThreshold) / 100.0

        // Initial check
        updateSystemLoad()

        // Periodic monitoring
        monitorTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSystemLoad()
            }
        }

        DevCamLogger.recording.debug("System load monitoring started (high: \(highThreshold)%, low: \(lowThreshold)%)")
    }

    /// Stops monitoring system load
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        cpuReadings.removeAll()
    }

    /// Updates thresholds
    func setThresholds(high: Int, low: Int) {
        self.highThreshold = Double(high) / 100.0
        self.lowThreshold = Double(low) / 100.0
    }

    // MARK: - System Load Reading

    private func updateSystemLoad() {
        let cpuUsage = getCPUUsage()

        // Add to moving average
        cpuReadings.append(cpuUsage)
        if cpuReadings.count > averageWindow {
            cpuReadings.removeFirst()
        }

        // Calculate average
        let averageCPU = cpuReadings.reduce(0, +) / Double(cpuReadings.count)

        // Determine high load state with hysteresis
        let wasHighLoad = isHighLoad
        if !isHighLoad && averageCPU > highThreshold {
            isHighLoad = true
            DevCamLogger.recording.warning("High system load detected: \(Int(averageCPU * 100))%")
        } else if isHighLoad && averageCPU < lowThreshold {
            isHighLoad = false
            DevCamLogger.recording.info("System load normalized: \(Int(averageCPU * 100))%")
        }

        systemLoad = SystemLoad(cpuUsage: averageCPU, isHighLoad: isHighLoad)
    }

    /// Gets current CPU usage using host_statistics
    private func getCPUUsage() -> Double {
        var cpuInfo: host_cpu_load_info_data_t = host_cpu_load_info_data_t()
        var count: mach_msg_type_number_t = UInt32(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        let userTicks = Double(cpuInfo.cpu_ticks.0)
        let systemTicks = Double(cpuInfo.cpu_ticks.1)
        let idleTicks = Double(cpuInfo.cpu_ticks.2)
        let niceTicks = Double(cpuInfo.cpu_ticks.3)

        let totalTicks = userTicks + systemTicks + idleTicks + niceTicks
        let usedTicks = userTicks + systemTicks + niceTicks

        guard totalTicks > 0 else { return 0 }

        return usedTicks / totalTicks
    }
}
