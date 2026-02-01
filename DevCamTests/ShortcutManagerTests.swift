//
//  ShortcutManagerTests.swift
//  DevCamTests
//
//  Unit tests for ShortcutManager and related shortcut types.
//

import XCTest
import AppKit
@testable import DevCam

final class ShortcutManagerTests: XCTestCase {
    var settings: AppSettings!

    @MainActor
    override func setUp() async throws {
        settings = AppSettings()
        // Reset to defaults to ensure clean state
        settings.resetShortcutsToDefaults()
    }

    // MARK: - Default Shortcut Configs Tests

    @MainActor
    func testDefaultShortcutConfigs() async throws {
        let configs = settings.shortcutConfigs

        // Verify we have a config for each action
        XCTAssertEqual(configs.count, ShortcutAction.allCases.count,
                       "Should have one config for each ShortcutAction")

        // Check each action has a config
        for action in ShortcutAction.allCases {
            let config = configs.first { $0.action == action }
            XCTAssertNotNil(config, "Should have config for action: \(action.displayName)")

            // Verify default values
            if let config = config {
                XCTAssertEqual(config.keyCode, action.defaultKeyCode,
                               "Default keyCode should match for \(action.displayName)")
                XCTAssertEqual(config.modifierFlags, action.defaultModifiers,
                               "Default modifiers should match for \(action.displayName)")
                XCTAssertTrue(config.isEnabled, "Default config should be enabled")
            }
        }
    }

    @MainActor
    func testResetShortcutsToDefaults() async throws {
        // Modify a shortcut
        var config = settings.shortcutConfig(for: .exportLast30Seconds)
        config.keyCode = 99  // Change to arbitrary key
        config.isEnabled = false
        settings.updateShortcut(config)

        // Verify modification took effect
        let modifiedConfig = settings.shortcutConfig(for: .exportLast30Seconds)
        XCTAssertEqual(modifiedConfig.keyCode, 99)
        XCTAssertFalse(modifiedConfig.isEnabled)

        // Reset to defaults
        settings.resetShortcutsToDefaults()

        // Verify reset
        let resetConfig = settings.shortcutConfig(for: .exportLast30Seconds)
        XCTAssertEqual(resetConfig.keyCode, ShortcutAction.exportLast30Seconds.defaultKeyCode)
        XCTAssertTrue(resetConfig.isEnabled)
    }

    // MARK: - Display String Tests

    @MainActor
    func testShortcutConfigDisplayString() async throws {
        // Test default shortcuts with Command+Shift modifiers
        let exportConfig = settings.shortcutConfig(for: .exportLast30Seconds)

        // Default is Command+Shift+S (keyCode 1)
        // Display order: Control, Option, Shift, Command, then key
        // So Command+Shift should be "⇧⌘S"
        XCTAssertTrue(exportConfig.displayString.contains("⇧"),
                      "Display string should contain shift symbol")
        XCTAssertTrue(exportConfig.displayString.contains("⌘"),
                      "Display string should contain command symbol")
        XCTAssertTrue(exportConfig.displayString.contains("S"),
                      "Display string should contain key character")
        XCTAssertEqual(exportConfig.displayString, "⇧⌘S",
                       "Display string should be formatted correctly")
    }

    @MainActor
    func testShortcutConfigDisplayStringWithAllModifiers() async throws {
        // Create a config with all modifiers
        var config = ShortcutConfig.defaultConfig(for: .exportLast30Seconds)
        config.modifiers = NSEvent.ModifierFlags([.control, .option, .shift, .command]).rawValue

        let displayString = config.displayString

        // Verify all modifier symbols are present in correct order
        XCTAssertTrue(displayString.contains("⌃"), "Should contain control symbol")
        XCTAssertTrue(displayString.contains("⌥"), "Should contain option symbol")
        XCTAssertTrue(displayString.contains("⇧"), "Should contain shift symbol")
        XCTAssertTrue(displayString.contains("⌘"), "Should contain command symbol")

        // Verify order: Control, Option, Shift, Command, Key
        XCTAssertEqual(displayString, "⌃⌥⇧⌘S",
                       "Modifiers should appear in standard order")
    }

    @MainActor
    func testShortcutConfigDisplayStringForEachAction() async throws {
        // Verify display strings for all default actions
        let expectedStrings: [ShortcutAction: String] = [
            .exportLast30Seconds: "⇧⌘S",   // keyCode 1 = S
            .exportLast1Minute: "⇧⌘M",     // keyCode 46 = M
            .exportLast5Minutes: "⇧⌘L",    // keyCode 37 = L
            .togglePauseResume: "⇧⌘P"      // keyCode 35 = P
        ]

        for (action, expectedString) in expectedStrings {
            let config = settings.shortcutConfig(for: action)
            XCTAssertEqual(config.displayString, expectedString,
                           "Display string for \(action.displayName) should be \(expectedString)")
        }
    }

    // MARK: - Conflict Detection Tests

    @MainActor
    func testConflictDetection() async throws {
        let shortcutManager = ShortcutManager(settings: settings)

        // Get the config for exportLast30Seconds (default: Command+Shift+S)
        let export30Config = settings.shortcutConfig(for: .exportLast30Seconds)

        // Test detecting conflict with same keyCode and modifiers
        let conflict = shortcutManager.detectConflict(
            keyCode: export30Config.keyCode,
            modifiers: export30Config.modifierFlags,
            excludingAction: nil
        )

        XCTAssertEqual(conflict, .exportLast30Seconds,
                       "Should detect conflict with existing shortcut")
    }

    @MainActor
    func testConflictDetectionExcludingSelf() async throws {
        let shortcutManager = ShortcutManager(settings: settings)

        // Get the config for exportLast30Seconds
        let export30Config = settings.shortcutConfig(for: .exportLast30Seconds)

        // Test that excluding the same action doesn't report a conflict
        let conflict = shortcutManager.detectConflict(
            keyCode: export30Config.keyCode,
            modifiers: export30Config.modifierFlags,
            excludingAction: .exportLast30Seconds
        )

        XCTAssertNil(conflict,
                     "Should not detect conflict when excluding the same action")
    }

    @MainActor
    func testNoConflictWithDifferentKeyCode() async throws {
        let shortcutManager = ShortcutManager(settings: settings)

        // Test with a keyCode not used by any default shortcut
        let conflict = shortcutManager.detectConflict(
            keyCode: 99,  // Unused keyCode
            modifiers: [.command, .shift],
            excludingAction: nil
        )

        XCTAssertNil(conflict,
                     "Should not detect conflict with unused keyCode")
    }

    @MainActor
    func testNoConflictWithDifferentModifiers() async throws {
        let shortcutManager = ShortcutManager(settings: settings)

        // Test with same keyCode as export30Seconds but different modifiers
        let export30Config = settings.shortcutConfig(for: .exportLast30Seconds)

        let conflict = shortcutManager.detectConflict(
            keyCode: export30Config.keyCode,
            modifiers: [.command, .option],  // Different modifiers
            excludingAction: nil
        )

        XCTAssertNil(conflict,
                     "Should not detect conflict with different modifiers")
    }

    @MainActor
    func testConflictDetectionIgnoresDisabledShortcuts() async throws {
        // Disable the export30Seconds shortcut
        var config = settings.shortcutConfig(for: .exportLast30Seconds)
        config.isEnabled = false
        settings.updateShortcut(config)

        let shortcutManager = ShortcutManager(settings: settings)

        // Try to detect conflict with the disabled shortcut
        let conflict = shortcutManager.detectConflict(
            keyCode: config.keyCode,
            modifiers: config.modifierFlags,
            excludingAction: nil
        )

        XCTAssertNil(conflict,
                     "Should not detect conflict with disabled shortcut")
    }

    // MARK: - Export Duration Tests

    @MainActor
    func testShortcutActionExportDurations() async throws {
        // Verify export durations for each action
        XCTAssertEqual(ShortcutAction.exportLast30Seconds.exportDuration, 30,
                       "Export 30 seconds should have 30 second duration")

        XCTAssertEqual(ShortcutAction.exportLast1Minute.exportDuration, 60,
                       "Export 1 minute should have 60 second duration")

        XCTAssertEqual(ShortcutAction.exportLast5Minutes.exportDuration, 300,
                       "Export 5 minutes should have 300 second duration")

        XCTAssertNil(ShortcutAction.togglePauseResume.exportDuration,
                     "Toggle pause/resume should have no export duration")
    }

    // MARK: - Shortcut Action Display Names

    @MainActor
    func testShortcutActionDisplayNames() async throws {
        XCTAssertEqual(ShortcutAction.exportLast30Seconds.displayName,
                       "Export Last 30 Seconds")
        XCTAssertEqual(ShortcutAction.exportLast1Minute.displayName,
                       "Export Last 1 Minute")
        XCTAssertEqual(ShortcutAction.exportLast5Minutes.displayName,
                       "Export Last 5 Minutes")
        XCTAssertEqual(ShortcutAction.togglePauseResume.displayName,
                       "Pause/Resume Recording")
    }

    // MARK: - Shortcut Update Tests

    @MainActor
    func testUpdateShortcut() async throws {
        // Get initial config
        let initialConfig = settings.shortcutConfig(for: .exportLast1Minute)

        // Create modified config
        var modifiedConfig = initialConfig
        modifiedConfig.keyCode = 12  // Q key
        modifiedConfig.modifiers = NSEvent.ModifierFlags([.command, .option]).rawValue

        // Update
        settings.updateShortcut(modifiedConfig)

        // Verify update
        let updatedConfig = settings.shortcutConfig(for: .exportLast1Minute)
        XCTAssertEqual(updatedConfig.keyCode, 12,
                       "KeyCode should be updated")
        XCTAssertEqual(updatedConfig.modifierFlags, [.command, .option],
                       "Modifiers should be updated")
    }

    // MARK: - ShortcutConfig Equality Tests

    @MainActor
    func testShortcutConfigEquality() async throws {
        let config1 = ShortcutConfig.defaultConfig(for: .exportLast30Seconds)
        let config2 = ShortcutConfig.defaultConfig(for: .exportLast30Seconds)

        XCTAssertEqual(config1, config2,
                       "Identical configs should be equal")

        var config3 = config1
        config3.keyCode = 99

        XCTAssertNotEqual(config1, config3,
                          "Configs with different keyCodes should not be equal")
    }
}
