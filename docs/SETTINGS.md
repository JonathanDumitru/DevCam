# DevCam Settings Reference

Status: Preferences UI is available with General, Clips, and Privacy tabs. Recording and shortcut customization are not implemented.

## General

### Save Location
- Folder where clips are exported
- Selected via the macOS file picker
- Changes take effect on next launch (current exporter uses the location set at startup)

### Launch at Login
- Stores the preference only; login item setup is not implemented

### Notifications
- Controls whether export notifications are shown
- Changes take effect on next launch

## Clips
- Shows recent exports (most recent first)
- Actions: open clip, reveal in Finder, delete clip
- "Clear All" clears the list but does not delete files

## Privacy
- Shows screen recording permission status
- Button to open System Settings if permission is missing
- Summarizes local-only storage and buffer/clip locations

## Not Implemented Yet
- Recording tab (buffer duration, display selection, cursor capture)
- Resolution selection (720p through native)
- Forward-recording mode for longer-than-15-minute clips
- Shortcuts tab (custom hotkeys)
- Advanced tools (reset permissions, open logs)
