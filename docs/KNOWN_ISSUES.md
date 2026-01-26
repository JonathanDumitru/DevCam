# DevCam Known Issues (Beta)

Last updated: 2026-01-26 (v1.2 beta)

## Active Issues
- Console log spam: "Sample buffer has no image buffer" can appear repeatedly during capture.
  - Impact: noisy logs, no confirmed data loss.
  - Workaround: none; include a 10-30 second log snippet in reports.

- Energy spikes when opening Preferences or revealing files.
  - Impact: brief, visible in Activity Monitor energy impact.
  - Workaround: none; note if spikes persist while idle.

## Known Limitations
- No audio recording.
- Buffer length is fixed at 15 minutes.
- No forward-recording mode or clips longer than 15 minutes.
- Shortcuts are app-local (not global).
- Launch at login is a stored preference only.
- Save location, notifications, and recording quality apply after restart.
- No display selection; DevCam records the primary display.

## Fixed Recently
- Menubar icon hidden on launch (fixed 2026-01-25).
- Intermittent zero-byte segment files (fixed 2026-01-25).

## Reporting
Use `docs/FEEDBACK_TEMPLATE.md` and attach logs per `docs/DIAGNOSTICS.md`.
