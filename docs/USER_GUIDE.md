# DevCam User Guide

Status: Menubar UI and export workflow are implemented. Current builds may fail to start recording due to a known AVAssetWriterInput settings issue; see `docs/TROUBLESHOOTING.md` and `docs/CURRENT_STATE.md`.

## Quick Start
1. Launch DevCam from Applications.
2. Grant Screen Recording permission when prompted.
3. Open Preferences to confirm save location and notifications.
4. DevCam starts recording automatically (when recording starts successfully, the buffer time increases in the menubar).

## Menubar Overview
DevCam runs in the macOS menubar. The status area shows:
- Recording state (Recording, Paused, or Error)
- Buffer duration while recording
- Export progress when saving a clip

Menu actions:
- Save Last 5 Minutes
- Save Last 10 Minutes
- Save Last 15 Minutes
- Preferences
- Quit DevCam

## Saving Clips
You can save clips in two ways:
- From the menubar menu
- With keyboard shortcuts (when DevCam is the active app)

Export behavior:
- Default filenames: DevCam_YYYY-MM-DD_HH-MM-SS.mp4
- Clips are saved to the selected folder
- Export progress is shown in the menubar

Notes:
- Save actions are disabled until the buffer has content.
- DevCam continues recording during exports.

## Keyboard Shortcuts
Default shortcuts:
- Save last 5 minutes: Command-Shift-5
- Save last 10 minutes: Command-Shift-6
- Save last 15 minutes: Command-Shift-7

Shortcuts are app-local and not customizable in current builds.

## Preferences
Preferences are divided into tabs:
- General: save location, launch at login (preference only), notifications
- Clips: recent exports and quick actions
- Privacy: local-only data handling information and permission status

See SETTINGS.md for details.

## Storage and Buffer
DevCam maintains a rolling buffer of 1-minute segments:
- Fixed buffer size: 15 minutes (15 segments)
- Old segments are deleted automatically
- Buffer storage path: `~/Library/Application Support/DevCam/buffer/`

To avoid failed exports, keep at least 2 GB free disk space.

## Notifications
When enabled, DevCam shows macOS notifications for:
- Export success

Notification preference changes take effect on next launch.

## Logs
If something goes wrong, DevCam logs events to:
- macOS unified logging (view in Console.app, filter for "DevCam")

Terminal:
```
log show --last 1h --predicate 'process == "DevCam"' --style compact
```

## Known Limitations
- Global hotkeys are not supported; shortcuts only work when DevCam is active.
- Launch at login is stored as a preference only.
- Save location and notification changes take effect on next launch.
- No forward-recording mode for longer-than-15-minute clips.
- No audio recording.

## Uninstall
To remove DevCam completely:
1. Quit DevCam.
2. Delete DevCam.app.
3. Remove local data (optional):
   - `~/Library/Application Support/DevCam/`
   - `~/Library/Logs/DevCam/` (if present from older builds)
   - `~/Library/Preferences/Jonathan-Hines-Dumitru.DevCam.plist`
