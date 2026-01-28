//
//  BatteryMonitor.swift
//  DevCam
//
//  Monitors battery state and power source for battery-aware recording mode
//

import Foundation
import IOKit.ps
import Combine

/// Battery state information
struct BatteryState {
    let isOnBattery: Bool
    let batteryLevel: Int  // 0-100
    let isCharging: Bool
    let timeRemaining: Int? // Minutes, nil if unknown

    static let unknown = BatteryState(isOnBattery: false, batteryLevel: 100, isCharging: false, timeRemaining: nil)
}

/// Monitors battery state using IOKit Power Sources
@MainActor
class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    @Published private(set) var batteryState: BatteryState = .unknown
    @Published private(set) var isLowBattery: Bool = false

    private var monitorTimer: Timer?
    private let checkInterval: TimeInterval = 30.0 // Check every 30 seconds

    private var lowBatteryThreshold: Int = 20

    init() {
        updateBatteryState()
    }

    /// Starts monitoring battery state
    func startMonitoring(lowBatteryThreshold: Int = 20) {
        self.lowBatteryThreshold = lowBatteryThreshold

        // Initial check
        updateBatteryState()

        // Periodic monitoring
        monitorTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateBatteryState()
            }
        }

        DevCamLogger.recording.debug("Battery monitoring started (threshold: \(lowBatteryThreshold)%)")
    }

    /// Stops monitoring battery state
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    /// Updates the low battery threshold
    func setLowBatteryThreshold(_ threshold: Int) {
        self.lowBatteryThreshold = threshold
        updateLowBatteryStatus()
    }

    // MARK: - Battery State Reading

    private func updateBatteryState() {
        let state = readBatteryState()
        self.batteryState = state
        updateLowBatteryStatus()
    }

    private func updateLowBatteryStatus() {
        let wasLowBattery = isLowBattery
        isLowBattery = batteryState.isOnBattery && batteryState.batteryLevel <= lowBatteryThreshold

        if isLowBattery && !wasLowBattery {
            DevCamLogger.recording.warning("Low battery detected: \(self.batteryState.batteryLevel)%")
        }
    }

    private func readBatteryState() -> BatteryState {
        // Get power source info
        guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSources = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() as? [CFTypeRef],
              let source = powerSources.first else {
            return .unknown
        }

        guard let description = IOPSGetPowerSourceDescription(powerSourcesInfo, source)?.takeUnretainedValue() as? [String: Any] else {
            return .unknown
        }

        // Extract values
        let isOnBattery: Bool
        if let powerSource = description[kIOPSPowerSourceStateKey as String] as? String {
            isOnBattery = (powerSource == kIOPSBatteryPowerValue as String)
        } else {
            isOnBattery = false
        }

        let batteryLevel = description[kIOPSCurrentCapacityKey as String] as? Int ?? 100

        let isCharging: Bool
        if let charging = description[kIOPSIsChargingKey as String] as? Bool {
            isCharging = charging
        } else {
            isCharging = false
        }

        let timeRemaining: Int?
        if let time = description[kIOPSTimeToEmptyKey as String] as? Int, time > 0 {
            timeRemaining = time
        } else {
            timeRemaining = nil
        }

        return BatteryState(
            isOnBattery: isOnBattery,
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            timeRemaining: timeRemaining
        )
    }
}

// MARK: - Battery State Extensions

extension BatteryState: CustomStringConvertible {
    var description: String {
        if isOnBattery {
            if let time = timeRemaining {
                return "\(batteryLevel)% (\(time) min remaining)"
            }
            return "\(batteryLevel)% (on battery)"
        }
        return isCharging ? "\(batteryLevel)% (charging)" : "\(batteryLevel)% (plugged in)"
    }
}
