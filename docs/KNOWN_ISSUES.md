# DevCam Known Issues (Beta)

Last updated: 2026-01-31 (v1.2.2 beta)

## Active Issues
- Exported clips are video-only even when audio capture is enabled (audio tracks are not stitched during export).
- Microphone capture mode is not wired yet; selecting it yields silent exports.
- All-displays mode is not implemented; it falls back to the primary display.
- Battery monitoring changes require restart (monitoring is initialized on launch).
- Notification permission prompts are only requested on launch when notifications are enabled.

## Known Limitations
- Buffer length is fixed at 15 minutes.
- No forward-recording mode for clips longer than 15 minutes.
- Shortcuts are not customizable.

## Fixed Recently
- Energy spikes when opening Preferences (fixed 2026-01-26) - window and popover now reuse instead of recreate.
- Console log spam from metadata frames (fixed 2026-01-26) - added rate-limited logging.
- Save location and notifications requiring restart (fixed 2026-01-26) - now apply immediately.
- Launch at login not functional (fixed 2026-01-26) - now uses ServiceManagement.
- Menubar icon hidden on launch (fixed 2026-01-25).
- Intermittent zero-byte segment files (fixed 2026-01-25).

## Reporting
Use `docs/FEEDBACK_TEMPLATE.md` and attach logs per `docs/DIAGNOSTICS.md`.
