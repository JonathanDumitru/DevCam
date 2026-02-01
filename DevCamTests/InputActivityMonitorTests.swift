//
//  InputActivityMonitorTests.swift
//  DevCamTests
//
//  Tests for InputActivityMonitor
//

import XCTest
@testable import DevCam

@MainActor
final class InputActivityMonitorTests: XCTestCase {

    func testTimeSinceLastInputIncreasesOverTime() async {
        let monitor = InputActivityMonitor.shared

        // Record initial time
        let initialTime = monitor.timeSinceLastInput

        // Wait a bit
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Time should have increased
        let laterTime = monitor.timeSinceLastInput
        XCTAssertGreaterThan(laterTime, initialTime)
    }

    func testHasAccessibilityPermissionReturnsBoolean() async {
        // This just verifies the API works, not the actual permission state
        let hasPermission = InputActivityMonitor.hasAccessibilityPermission
        XCTAssertNotNil(hasPermission)
    }
}
