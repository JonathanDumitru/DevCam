# DevCam Documentation

This directory contains the user, developer, and project documentation for DevCam.

## Workflow Note
The documentation is currently a workflow test using multiple tools. See WORKFLOW.md for details.

## Documentation Overview

### For Users
- User Guide: USER_GUIDE.md
- Shortcuts Reference: SHORTCUTS.md
- Settings Reference: SETTINGS.md
- Troubleshooting: TROUBLESHOOTING.md
- FAQ: FAQ.md
- Privacy Policy: PRIVACY.md

### For Developers
- Architecture Guide: ARCHITECTURE.md
- ScreenCaptureKit Integration: SCREENCAPTUREKIT.md
- Building from Source: BUILDING.md
- Contributing: CONTRIBUTING.md
- Security Policy: SECURITY.md
- Changelog: CHANGELOG.md
- Release Process: RELEASE_PROCESS.md

### For Project
- Roadmap: ROADMAP.md
- Support: SUPPORT.md
- Workflow Notes: WORKFLOW.md
- Implementation Plan: plans/2026-01-22-devcam-implementation.md
- Current State Snapshot: CURRENT_STATE.md

## Project Structure
```
DevCam/
├── DevCam/              # Main application code
│   ├── Core/           # Core managers (Recording, Buffer, Export)
│   ├── UI/             # SwiftUI views and windows
│   ├── Utilities/      # Helper classes (Permissions, Storage, Logger)
│   └── Models/         # Data models
├── DevCamTests/         # Unit tests
└── docs/               # This documentation
```
