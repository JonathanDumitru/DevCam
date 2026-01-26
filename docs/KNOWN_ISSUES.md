# DevCam Known Issues (Beta)

Last updated: 2026-01-26 (v1.2.1 beta)

## Active Issues
- Energy spikes when opening Preferences or revealing files.
  - Impact: brief, visible in Activity Monitor energy impact.
  - Workaround: none; note if spikes persist while idle.

## Known Limitations
- No audio recording.
- Buffer length is fixed at 15 minutes.
- No forward-recording mode or clips longer than 15 minutes.
- Shortcuts are app-local (not global).
- Recording quality changes apply after restart (requires stream reconfiguration).
- No display selection; DevCam records the primary display.

## Fixed Recently
- Console log spam from metadata frames (fixed 2026-01-26) - Added rate-limited logging.
- Save location and notifications requiring restart (fixed 2026-01-26) - Now apply immediately.
- Launch at login not functional (fixed 2026-01-26) - Now uses ServiceManagement framework.
- Menubar icon hidden on launch (fixed 2026-01-25).
- Intermittent zero-byte segment files (fixed 2026-01-25).

## Reporting
Use `docs/FEEDBACK_TEMPLATE.md` and attach logs per `docs/DIAGNOSTICS.md`.
