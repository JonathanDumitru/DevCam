# DevCam Privacy Policy

Last updated: 2026-01-22

## Our Privacy Commitment
DevCam is designed with privacy as a core principle. Your recordings are yours
alone. We do not collect, transmit, or have access to your data.

## Data Collection
Short answer: we collect nothing.

DevCam:
- Does not collect analytics
- Does not use telemetry
- Does not include crash reporting
- Does not connect to the internet
- Does not include third-party SDKs
- Does not use advertising frameworks

## What DevCam Stores Locally
All data stays on your device.

### 1) Rolling Buffer
- Location: ~/Library/Application Support/DevCam/buffer/
- Contains: up to 15 minutes of screen recording segments
- Automatically deleted: yes, oldest segments removed as new ones are created
- On quit: buffer files remain on disk until overwritten or deleted
- User access: you can view or delete these files directly
- Size: typically 0.5 to 2 GB depending on resolution and bitrate

### 2) Saved Clips
- Location: your chosen save folder
- Contains: clips you explicitly export
- Automatically deleted: no, you manage these files
- User access: full access, you own the files
- Size: varies by duration and quality

### 3) Settings
- Location: ~/Library/Preferences/Jonathan-Hines-Dumitru.DevCam.plist
- Contains: save location, launch at login preference, notifications, buffer size
- Automatically deleted: no (remove manually)
- User access: readable with defaults read

### 4) Logs
- Location: macOS unified logging (view in Console.app)
- Contains: error messages and recording events (no frame data)
- Retention: managed by macOS log store
- User access: you can view logs in Console.app or via `log show`

## Permissions Required

### Screen Recording Permission
Why it is needed:
- Required to capture your screen content

How it is used:
- ScreenCaptureKit captures frames
- Frames are encoded and saved locally
- No frames are sent anywhere

Revoke any time:
- System Settings -> Privacy and Security -> Screen Recording

### File System Access
Why it is needed:
- To save clips to your chosen location

How it is used:
- You select a folder using the macOS file picker
- DevCam is not sandboxed, so macOS does not enforce folder-only access
- The app is designed to write recordings only to the folder you choose

## What DevCam Does Not Do

### No Network Access
DevCam does not include network features and does not send data to the internet.
Because the app is not sandboxed, macOS does not enforce network restrictions;
this is a design choice rather than an OS-level constraint.

You can verify this:
```
codesign -d --entitlements - /Applications/DevCam.app
```
Default release install path: /Applications/DevCam.app
Note: network entitlements only apply to sandboxed apps.

### No Third-Party Services
DevCam uses only Apple frameworks:
- ScreenCaptureKit
- AVFoundation
- SwiftUI

## User Control

### View Buffer Files
```
open ~/Library/Application\\ Support/DevCam/buffer/
```

### Delete Buffer Manually
```
rm -rf ~/Library/Application\\ Support/DevCam/buffer/*
```

### View Logs
Console.app:
- Open Console.app and filter for "DevCam"

Terminal:
```
log show --last 1h --predicate 'process == "DevCam"' --style compact
```

### Uninstall Completely
1. Quit DevCam
2. Delete DevCam.app
3. Remove local data (optional):
   - ~/Library/Application Support/DevCam/
   - ~/Library/Logs/DevCam/ (if present from older builds)
   - ~/Library/Preferences/Jonathan-Hines-Dumitru.DevCam.plist

## macOS Privacy Protections

### App Sandbox (Not Enabled)
- DevCam does not use the App Sandbox
- File access is governed by standard macOS permissions for your user account

### Permission System
- Screen recording permission required
- User can revoke any time
- macOS shows a system indicator when recording

### Notarization
- Apple scans the app for malware
- Ensures distributed apps are signed and unmodified

## Data Retention

| Data type | Retention | Controlled by |
| --- | --- | --- |
| Rolling buffer | 15 minutes max | Automatic deletion |
| Saved clips | Until you delete | You |
| Settings | Until you delete | You |
| Logs | Managed by macOS log store | macOS |

## Changes to This Policy
If we change privacy practices, we will update this document and note the date.

## Questions or Concerns
Contact: jonathan@hinesdumitru.online
