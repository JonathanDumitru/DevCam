//
//  LaunchAtLoginManagerTests.swift
//  DevCamTests
//
//  Tests for LaunchAtLoginManager functionality
//

import XCTest
import ServiceManagement
@testable import DevCam

final class LaunchAtLoginManagerTests: XCTestCase {

    // MARK: - Initialization Tests

    func testManagerInitialization() {
        // Given/When
        let manager = LaunchAtLoginManager.shared

        // Then
        XCTAssertNotNil(manager, "LaunchAtLoginManager should initialize successfully")
    }

    // MARK: - Enable/Disable Cycle Tests

    func testEnableDisableCycle() throws {
        // Given
        let manager = LaunchAtLoginManager.shared

        // Store original state to restore after test
        let originalState = manager.isEnabled

        // When: Enable
        try manager.enable()

        // Then: Should be enabled
        XCTAssertTrue(manager.isEnabled, "Launch at login should be enabled after calling enable()")

        // When: Disable
        try manager.disable()

        // Then: Should be disabled
        XCTAssertFalse(manager.isEnabled, "Launch at login should be disabled after calling disable()")

        // Cleanup: Restore original state
        if originalState {
            try manager.enable()
        }
    }

    // MARK: - State Reflection Tests

    func testStatusReflectsSystemState() {
        // Given
        let manager = LaunchAtLoginManager.shared
        let systemStatus = SMAppService.mainApp.status

        // Then
        XCTAssertEqual(
            manager.isEnabled,
            systemStatus == .enabled,
            "Manager isEnabled should reflect actual system status"
        )
    }

    // MARK: - Multiple Enable Calls Tests

    func testMultipleEnableCalls() throws {
        // Given
        let manager = LaunchAtLoginManager.shared
        let originalState = manager.isEnabled

        // When: Enable twice
        try manager.enable()
        try manager.enable()

        // Then: Should still be enabled without error
        XCTAssertTrue(manager.isEnabled, "Multiple enable calls should be idempotent")

        // Cleanup
        try manager.disable()
        if originalState {
            try manager.enable()
        }
    }

    func testMultipleDisableCalls() throws {
        // Given
        let manager = LaunchAtLoginManager.shared
        let originalState = manager.isEnabled

        // When: Disable twice
        try manager.disable()
        try manager.disable()

        // Then: Should still be disabled without error
        XCTAssertFalse(manager.isEnabled, "Multiple disable calls should be idempotent")

        // Cleanup
        if originalState {
            try manager.enable()
        }
    }
}
