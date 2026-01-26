# Changelog

All notable changes to this project will be documented in this file.
The format is based on Keep a Changelog, and this project adheres to
Semantic Versioning.

Note: GitHub compare/release links will go live once the repository is published (coming soon).

## [Unreleased]
No changes yet.

## [1.2.0] - 2026-01-26
### Fixed
- **CRITICAL**: Fixed menubar icon not visible on launch (2026-01-25)
  - Root cause: Configuration conflict between `LSUIElement=true` in Info.plist and programmatic `NSApp.setActivationPolicy(.accessory)` call caused macOS to hide all UI including menubar items
  - Solution: Removed redundant programmatic activation policy call, relying solely on Info.plist setting (standard approach for menubar-only apps)
  - File: `DevCamApp.swift:72-77`

- **CRITICAL**: Fixed intermittent zero-byte video segment files (~5% failure rate) (2026-01-25)
  - Root cause: Race condition where AVAssetWriter's `finishWriting()` was called before `startWriting()` when ScreenCaptureKit sent only metadata frames (no pixel buffers) in first 60 seconds of a segment
  - Solution: Start AVAssetWriter immediately in `startNewSegment()` with `atSourceTime: .zero` instead of waiting for first video frame, eliminating state machine violation
  - Added diagnostic logging to detect and report any zero-byte files
  - Verified with 19 consecutive segments - 0% failure rate after fix
  - Files: `RecordingManager.swift:313-328, 357-368, 404-414`

### Added
- Initial release planning

## [0.1.0] - 2026-01-22
### Added
- Initial public release

[Unreleased]: https://github.com/JonathanDumitru/devcam/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/JonathanDumitru/devcam/compare/v0.1.0...v1.2.0
[0.1.0]: https://github.com/JonathanDumitru/devcam/releases/tag/v0.1.0
