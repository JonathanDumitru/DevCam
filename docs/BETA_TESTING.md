# DevCam Beta Testing Guide

Status: This guide reflects current beta functionality and limitations (v1.2).

## Goals
- Validate continuous recording stability
- Validate retroactive clip exports (1-15 minutes)
- Validate display selection and display switching behavior
- Validate adaptive quality and battery modes
- Capture performance and energy observations
- Identify permission and logging issues

## System Requirements
- macOS 13.0+
- Screen Recording permission
- 2 GB free disk space (more for higher quality)
- Any display setup (primary by default, specific display selection supported)

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
- Advanced clip window for timeline trim or custom duration, with annotations.
- System-wide keyboard shortcuts for 5/10/15 minutes (Cmd-Option-5/6/7).
- Preferences: save location, recording quality (Low/Medium/High), launch at login, notifications.
- Recording tab: display selection, audio capture toggle, adaptive quality, battery mode.
- Clips browser with tag filtering, detail view, open/reveal/delete/clear actions.
- Health tab with stats, disk usage, recent errors, and exportable report.
- Privacy tab with permission status and a System Settings shortcut.

## Known Limitations
- Exported clips are video-only even if audio capture is enabled.
- Microphone capture is not implemented.
- All-displays mode is not implemented.
- Buffer length fixed at 15 minutes.
- Shortcuts are not customizable.
- Recording quality changes require restart.
- Battery monitoring changes require restart.
- No forward-recording mode or clips longer than 15 minutes.

## Known Issues
- See `docs/KNOWN_ISSUES.md` for the current list.

## What To Test
- Launch and menubar visibility.
- Recording starts automatically and buffer time increases.
- Save Clip exports at multiple durations.
- Advanced clip export with custom durations and annotations.
- Display switching behavior (buffer cleared, recording restarts).
- Preferences persistence and restart-required behavior.
- Clips tab actions (open, reveal, delete, clear, tag filtering).
- Health tab export report.
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
