# DevCam Settings Reference

Status: Preferences window includes General, Recording, Clips, Health, and Privacy tabs. Most changes apply immediately; recording quality and some monitoring settings require a restart.

## General

### Save Location
- Folder where clips are exported
- Selected via the macOS file picker
- Applies immediately to new exports

### Recording Quality
- Low (720p), Medium (1080p), High (native resolution)
- Changes affect capture resolution and file size
- Requires restart (stream reconfiguration)

### Launch at Login
- Automatically launches DevCam when you log in to macOS
- Uses ServiceManagement (macOS 13.0+)
- Registers the app in System Settings > General > Login Items
- State syncs with system settings on app launch
- If registration fails, an error alert appears with troubleshooting guidance

### Notifications
- Controls whether export notifications are shown
- Applies immediately for new exports
- If enabled after launch, you may need to relaunch DevCam to trigger the system permission prompt

## Recording

### Display Selection
- Primary Display: records the largest connected display
- Specific Display: choose a display from the list
- All Displays: not implemented; falls back to primary
- Switching displays while recording restarts capture and clears the buffer

### Audio Capture
- None / System / Microphone / System + Microphone available in the UI
- System audio uses ScreenCaptureKit's audio output
- Microphone capture is not wired yet, and exported clips are currently video-only

### Adaptive Quality
- Automatically lowers quality when CPU usage is high
- Thresholds for reduce/restore are adjustable
- Applies immediately when toggled

### Battery Mode
- Ignore Battery / Reduce Quality on Battery / Pause on Low Battery
- Low battery threshold is configurable
- Monitoring is initialized on launch; changes take effect after restart

## Clips
- Shows recent exports (most recent first)
- Supports tag filtering and annotation indicators
- Actions: open clip, reveal in Finder, delete clip, view details
- "Clear All" clears the list but does not delete files

## Health
- Session and lifetime stats (uptime, recording time, exports, errors, recoveries)
- Buffer size and available disk space
- Recent errors and exportable health report

## Privacy
- Screen recording permission status
- Button to open System Settings if permission is missing
- Summary of local-only storage and buffer/clip locations

## Not Implemented Yet
- All-displays capture
- Microphone capture and audio export pipeline
- Customizable hotkeys
- Forward-recording mode for clips longer than 15 minutes
