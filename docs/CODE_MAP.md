# Code Map

This document links the main source files to their responsibilities.

## Entry Point
- DevCam/DevCam/DevCamApp.swift: AppDelegate setup, manager wiring, status bar setup, starts recording.

## Core Recording Pipeline
- DevCam/DevCam/Core/RecordingManager.swift: ScreenCaptureKit stream, segment creation, recording lifecycle.
- DevCam/DevCam/Core/BufferManager.swift: Rolling on-disk buffer, segment selection for exports.
- DevCam/DevCam/Core/ClipExporter.swift: Composition and export flow, notifications, recent clips.
- DevCam/DevCam/Core/AppSettings.swift: @AppStorage preferences and save location.

## UI
- DevCam/DevCam/UI/MenuBarView.swift: Menubar popover, save actions, export progress.
- DevCam/DevCam/UI/PreferencesWindow.swift: Preferences window and tab routing.
- DevCam/DevCam/UI/GeneralTab.swift: Save location, notifications, quality settings.
- DevCam/DevCam/UI/ClipsTab.swift: Recent clips list and actions.
- DevCam/DevCam/UI/PrivacyTab.swift: Screen recording permission status.
- DevCam/DevCam/UI/AdvancedClipWindow.swift: Slider-based clip duration save.

## Models
- DevCam/DevCam/Models/SegmentInfo.swift: Buffer segment metadata.
- DevCam/DevCam/Models/ClipInfo.swift: Exported clip metadata.

## Utilities
- DevCam/DevCam/Utilities/PermissionManager.swift: Screen recording permission checks.
- DevCam/DevCam/Utilities/KeyboardShortcutHandler.swift: Local hotkeys for save actions.
- DevCam/DevCam/Utilities/DevCamLogger.swift: OSLog categories and helpers.

## Tests
- DevCam/DevCamTests/RecordingManagerTests.swift: Recording lifecycle tests.
- DevCam/DevCamTests/BufferManagerTests.swift: Buffer rotation and selection logic.
- DevCam/DevCamTests/ClipExporterTests.swift: Export flow tests.
- DevCam/DevCamTests/ModelsTests.swift: Model coverage.
- DevCam/DevCamTests/PermissionManagerTests.swift: Permission checks.

## Supporting Files
- DevCam/DevCam/Info.plist: App metadata and permission keys.
- DevCam/DevCam/DevCam.entitlements: Screen capture entitlement.
- DevCam/run_and_debug.sh: Local run and debug helper script.
