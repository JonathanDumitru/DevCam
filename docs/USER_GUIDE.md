# DevCam User Guide

Status: Menubar UI, continuous recording, advanced export, display selection, and health dashboard are implemented. Recording quality changes require restart.

## Quick Start
1. Launch DevCam from Applications.
2. Grant Screen Recording permission when prompted.
3. Open Preferences to confirm save location and notifications.
4. DevCam starts recording automatically after onboarding/permission is complete.

## Menubar Overview
DevCam runs in the macOS menubar. The status area shows:
- Recording state (Recording, Paused, or Error)
- Buffer duration while recording
- Export progress when saving a clip

Menu actions:
- Display selector (quick switch between displays)
- Save Clip (duration slider + save button)
- Advanced... (timeline trim or custom duration + annotations)
- Preferences
- Quit DevCam

## Saving Clips
You can save clips in two ways:
- From the menubar menu
- With keyboard shortcuts (system-wide)

Export behavior:
- Default filenames: DevCam_YYYY-MM-DD_HH-MM-SS.mp4
- Clips are saved to the selected folder
- Export progress is shown in the menubar

Menubar save options:
- Save Clip slider supports 1-15 minute exports in 1-minute steps.
- Advanced... lets you set a custom duration or trim a timeline range.
- Advanced exports can include a title, notes, and tags.

Notes:
- Save actions are disabled until the buffer has content.
- DevCam continues recording during exports.

## Keyboard Shortcuts
Default shortcuts (system-wide):
- Save last 5 minutes: Command-Option-5
- Save last 10 minutes: Command-Option-6
- Save last 15 minutes: Command-Option-7

Behavior:
- Shortcuts are global, but they do not consume the keystroke (the foreground app still receives it).
- Customization is not supported in current builds.

## Preferences
Preferences are divided into tabs:
- General: save location, recording quality, launch at login, notifications
- Recording: display selection, audio capture, adaptive quality, battery mode
- Clips: recent exports, tags, and details
- Health: session/lifetime stats, disk usage, recent errors, exportable report
- Privacy: permission status and local-only storage details

Notes:
- Recording quality changes require restart.
- Switching displays while recording clears the buffer and restarts capture.
- Battery mode changes take effect after restart.
- Audio capture UI is present, but exported clips are currently video-only.

## Storage and Buffer
DevCam maintains a rolling buffer of 1-minute segments:
- Fixed buffer size: 15 minutes (15 segments)
- Old segments are deleted automatically
- Buffer storage path: ~/Library/Application Support/DevCam/buffer/

To avoid failed exports, keep at least 2 GB free disk space.

## Notifications
When enabled, DevCam shows notifications for:
- Export success
- Critical alerts (disk space, permission loss, recording recovery)

If notifications are enabled after launch, you may need to relaunch DevCam to trigger the system permission prompt.

## Logs
If something goes wrong, DevCam logs events to:
- macOS unified logging (view in Console.app, filter for "DevCam")

Terminal:
```
log show --last 1h --predicate 'process == "DevCam"' --style compact
```

## Known Limitations
- Forward-recording mode (longer than 15 minutes) is not supported.
- All-displays capture is not implemented.
- Microphone capture is not implemented, and exported clips are video-only.
- Battery monitoring changes require restart.

## Uninstall
To remove DevCam completely:
1. Quit DevCam.
2. Delete DevCam.app.
3. Remove local data (optional):
   - ~/Library/Application Support/DevCam/
   - ~/Library/Logs/DevCam/ (if present from older builds)
   - ~/Library/Preferences/Jonathan-Hines-Dumitru.DevCam.plist
