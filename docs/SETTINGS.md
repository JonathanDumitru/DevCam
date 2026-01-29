# DevCam Settings Reference

Status: Preferences UI is available with General, Clips, and Privacy tabs. Recording quality selection is implemented; shortcut customization is not.

## General

### Save Location
- Folder where clips are exported
- Selected via the macOS file picker
- Changes apply immediately for new exports

### Recording Quality
- Low (720p), Medium (1080p), High (native resolution)
- Changes affect capture resolution and file size
- Changes take effect after restart

### Launch at Login
- Automatically launches DevCam when you log in to macOS
- Uses the ServiceManagement framework (macOS 13.0+ required)
- Registers the app in System Settings > General > Login Items
- State syncs with system settings on app launch
- If registration fails, an error alert appears with troubleshooting guidance

### Notifications
- Controls whether export notifications are shown
- Changes apply immediately for new notifications

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
- Forward-recording mode for longer-than-15-minute clips
- Shortcuts tab (custom hotkeys)
- Advanced tools (reset permissions, open logs)
