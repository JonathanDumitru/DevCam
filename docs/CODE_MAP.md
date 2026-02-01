# Code Map

This document links the main source files to their responsibilities.

## Entry Point
- DevCam/DevCam/DevCamApp.swift: AppDelegate setup, manager wiring, status bar setup, starts recording.

## Core Recording Pipeline
- DevCam/DevCam/Core/RecordingManager.swift: ScreenCaptureKit stream, segment creation, recording lifecycle, recovery.
- DevCam/DevCam/Core/BufferManager.swift: Rolling on-disk buffer, segment selection for exports.
- DevCam/DevCam/Core/ClipExporter.swift: Composition and export flow, notifications, recent clips.
- DevCam/DevCam/Core/AppSettings.swift: @AppStorage preferences and save location.
- DevCam/DevCam/Core/BatteryMonitor.swift: Battery state monitoring for pause/reduce modes.
- DevCam/DevCam/Core/SystemLoadMonitor.swift: CPU load monitoring for adaptive quality.
- DevCam/DevCam/Core/HealthStats.swift: Session/lifetime stats and health reporting.

## UI
- DevCam/DevCam/UI/MenuBarView.swift: Menubar popover, save actions, export progress, display quick switch.
- DevCam/DevCam/UI/PreferencesWindow.swift: Preferences window and tab routing.
- DevCam/DevCam/UI/GeneralTab.swift: Save location, notifications, quality settings, launch at login.
- DevCam/DevCam/UI/RecordingTab.swift: Display selection, audio capture, adaptive quality, battery mode.
- DevCam/DevCam/UI/ClipsTab.swift: Recent clips list, tags, details.
- DevCam/DevCam/UI/HealthTab.swift: Health dashboard and exportable report.
- DevCam/DevCam/UI/PrivacyTab.swift: Screen recording permission status.
- DevCam/DevCam/UI/AdvancedClipWindow.swift: Timeline trim, custom duration, annotations.
- DevCam/DevCam/UI/OnboardingView.swift: First-launch onboarding and permission guidance.
- DevCam/DevCam/UI/DisplaySwitchConfirmationView.swift: Display switch confirmation dialog.

## Models
- DevCam/DevCam/Models/SegmentInfo.swift: Buffer segment metadata.
- DevCam/DevCam/Models/ClipInfo.swift: Exported clip metadata.

## Utilities
- DevCam/DevCam/Utilities/PermissionManager.swift: Screen recording permission checks.
- DevCam/DevCam/Utilities/KeyboardShortcutHandler.swift: Global/local hotkeys for save actions.
- DevCam/DevCam/Utilities/LaunchAtLoginManager.swift: Login item registration.
- DevCam/DevCam/Utilities/DevCamLogger.swift: OSLog categories and critical alerts.

## Tests
- DevCam/DevCamTests/RecordingManagerTests.swift: Recording lifecycle tests.
- DevCam/DevCamTests/BufferManagerTests.swift: Buffer rotation and selection logic.
- DevCam/DevCamTests/ClipExporterTests.swift: Export flow tests.
- DevCam/DevCamTests/ModelsTests.swift: Model coverage.
- DevCam/DevCamTests/PermissionManagerTests.swift: Permission checks.

## Supporting Files
- DevCam/DevCam/Info.plist: App metadata and permission keys.
- DevCam/DevCam/DevCam.entitlements: App sandbox and capture entitlements.
- DevCam/run_and_debug.sh: Local run and debug helper script.
