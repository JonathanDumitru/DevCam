# DevCam Known Issues (Beta)

Last updated: 2026-01-26 (v1.2.2 beta)

## Active Issues
- Brief energy spikes when revealing files in Finder.
  - Cause: `NSWorkspace.selectFile` activates Finder and performs file system operations.
  - Impact: Brief spike visible in Activity Monitor; expected macOS behavior.
  - Status: Not a bug; standard system behavior when revealing files.

## Known Limitations
- No audio recording.
- Buffer length is fixed at 15 minutes.
- No forward-recording mode or clips longer than 15 minutes.
- Recording quality changes apply after restart (requires stream reconfiguration).
- No display selection; DevCam records the primary display.
- Keyboard shortcuts (⌘⌥5/6/7) only work when DevCam popover is open (App Store sandbox restriction).

## Fixed Recently
- Energy spikes when opening Preferences (fixed 2026-01-26) - Window and popover now reuse instead of recreate.
- Console log spam from metadata frames (fixed 2026-01-26) - Added rate-limited logging.
- Save location and notifications requiring restart (fixed 2026-01-26) - Now apply immediately.
- Launch at login not functional (fixed 2026-01-26) - Now uses ServiceManagement framework.
- Menubar icon hidden on launch (fixed 2026-01-25).
- Intermittent zero-byte segment files (fixed 2026-01-25).

## Reporting
Use `docs/FEEDBACK_TEMPLATE.md` and attach logs per `docs/DIAGNOSTICS.md`.
