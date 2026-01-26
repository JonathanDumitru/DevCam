# DevCam Beta Testing Guide

Status: This guide reflects current beta functionality and limitations (v1.2).

## Goals
- Validate continuous recording stability
- Validate retroactive clip exports (1-15 minutes)
- Validate preferences (save location, quality, notifications)
- Capture performance and energy observations
- Identify permission and logging issues

## System Requirements
- macOS 12.3+
- Screen Recording permission
- 2 GB free disk space (more for higher quality)
- Any display setup; DevCam records the primary display (largest resolution)

## Install / Update
- Use the provided beta build.
- If building from source, follow `docs/BUILDING.md`.

## Quick Start
1. Launch DevCam (menubar icon appears).
2. Grant Screen Recording permission if prompted.
3. Wait for the buffer timer to increment.
4. Use the menubar Save Clip slider or keyboard shortcuts.
5. Open Preferences to confirm save location and recording quality.

## Features In This Beta
- Menubar-only app with continuous recording and a rolling 15-minute buffer.
- Save Clip slider (1-15 minutes in 1-minute steps).
- Advanced clip window for custom start/end selection within the buffer.
- Keyboard shortcuts for 5/10/15 minutes (DevCam must be active).
- Preferences: save location, recording quality (Low/Medium/High), notifications.
- Clips browser with open, reveal, delete, and clear actions.
- Privacy tab with permission status and a System Settings shortcut.

## Known Limitations
- No audio recording.
- Buffer length fixed at 15 minutes.
- Shortcuts are app-local (not global).
- Launch at login is a stored preference only.
- Save location, notifications, and quality changes apply after restart.
- No display selection (records primary display only).
- No forward-recording mode or clips longer than 15 minutes.

## Known Issues
- Console spam: "Sample buffer has no image buffer" can appear during capture.
- Energy spikes may occur when opening Preferences or revealing files.

## What To Test
- Launch and menubar visibility.
- Recording starts automatically and buffer time increases.
- Save Clip exports at multiple durations.
- Advanced clip export with custom ranges.
- Preferences persistence and restart-required behavior.
- Clips tab actions (open, reveal, delete, clear).
- Permission flow when denied or granted.
- Sleep/wake pause and resume behavior.
- Performance on your hardware (CPU, memory, energy).

## Feedback
- Follow `docs/SUPPORT.md`.
- Include macOS version, hardware model, display setup, and steps to reproduce.
- Attach a 10-30 second log snippet for recording/export issues.
- Use `docs/FEEDBACK_TEMPLATE.md` for reports.
- See `docs/DIAGNOSTICS.md` for log and file locations.
- Check `docs/KNOWN_ISSUES.md` before reporting duplicates.

## Logs
- Console.app filter: "DevCam"
- Terminal:
```
log show --last 10m --predicate 'process == "DevCam"' --style compact
```

## Privacy
All data stays on your Mac. See `docs/PRIVACY.md`.
