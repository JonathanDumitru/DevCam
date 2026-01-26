# Building DevCam from Source

This guide covers setting up your development environment and building DevCam.

## Prerequisites

### Required Software
- Xcode 14.0 or later
  - Download from the Mac App Store or Apple Developer
  - Includes Swift 5.9+ compiler
  - Must include macOS 13.0+ SDK
- macOS 13.0 or later (Ventura+)
  - Required for ScreenCaptureKit and ServiceManagement frameworks
  - Development and testing must be on 13.0+
- Apple Developer account (optional for distribution)
  - Free tier is sufficient for local development
  - Required for code signing and distribution

### System Requirements
- 8 GB RAM minimum (16 GB recommended)
- 10 GB free disk space
- Admin access for installing Xcode

## Getting the Code

Note: The GitHub repository is coming soon; the clone URL will work once it is published.

```
# Clone repository
git clone https://github.com/JonathanDumitru/devcam.git
cd devcam

# No external dependencies to install - all Apple frameworks
```

## Opening the Project

1. Open Xcode
2. File > Open > select DevCam.xcodeproj
3. Wait for Xcode to index (30 to 60 seconds)

## Project Structure

```
DevCam.xcodeproj/
├── DevCam/              # Main target
│   ├── Core/           # Core logic
│   ├── UI/             # SwiftUI views
│   ├── Utilities/      # Helpers
│   ├── Models/         # Data models
│   └── Resources/      # Assets, Info.plist
├── DevCamTests/         # Test target
└── docs/               # Documentation
```

## Build Configurations

### Debug Build (Development)
Purpose: daily development with full debugging

Settings:
- Optimization: None (-Onone)
- Debug symbols: Yes
- Assertions: Enabled
- Signing: Development certificate

How to build:
1. Select DevCam scheme
2. Set destination to My Mac
3. Cmd-B to build
4. Cmd-R to run

Output:
- Location: DerivedData/DevCam/Build/Products/Debug/DevCam.app
- Size: larger due to debug info

### Release Build (Distribution)
Purpose: optimized build for distribution

Settings:
- Optimization: -O
- Debug symbols: Yes (separate file)
- Assertions: Disabled
- Signing: Distribution certificate

How to build:
1. Product > Scheme > Edit Scheme
2. Run > Build Configuration > Release
3. Cmd-B to build

Output:
- Location: DerivedData/DevCam/Build/Products/Release/DevCam.app

## Code Signing

### Local Development
1. Select the DevCam target in Xcode
2. Signing and Capabilities tab
3. Enable Automatically manage signing
4. Select your team (free or paid)

### Distribution
1. Create a distribution certificate in Apple Developer
2. Select distribution profile in Xcode
3. Archive: Product > Archive
4. Export with desired method:
   - Development: local testing
   - App Store: Mac App Store submission
   - Developer ID: outside App Store (requires notarization)

## Entitlements

DevCam requires these entitlements (DevCam.entitlements):

```
<key>com.apple.security.device.screen-capture</key>
<true/>
```

DevCam does not enable the App Sandbox.

Note: network entitlements apply only to sandboxed apps; DevCam does not include network features.

## Running Tests

### Unit Tests

```
# Command line
xcodebuild test -scheme DevCam -destination 'platform=macOS'

# Or in Xcode: Cmd-U
```

### Manual Testing (Recommended)
Status: Shortcuts are app-local; recording quality selection is implemented. Global shortcuts and buffer/display settings are not.
Before release:
1. Cold start: grant permissions, choose location
2. Recording: confirm recording starts automatically
3. Buffer rotation: record 20+ minutes
4. Clip export: save 1-15 minute clips via the menubar slider
5. Shortcuts: verify they work when DevCam is active
6. Preferences: change settings and verify persistence on next launch
7. Low disk space: test < 2 GB available
8. Display changes: connect and disconnect monitors
9. System sleep: verify pause and resume

### Minimum Performance Target (M1 Baseline)
Use this profile when validating minimum-spec Macs:
- Resolution: 1080p, 60fps
- Buffer: 15 minutes
- Workload: PiP overlay + Console.app running
- Actions: open Preferences, reveal a clip, save a 15-minute clip

Targets:
- CPU average <= 5% during steady recording (peaks <= 8% during UI actions)
- Memory <= 150 MB
- Energy impact low on average; brief spikes acceptable during UI actions
- Disk activity minimal during steady recording; temporary spikes during export/buffer rotation

## Debugging

### Xcode Debugger
- Set breakpoints with Cmd-\\
- Use po in the console to inspect values
- Debug View Hierarchy for UI issues

### Logs
DevCam logs to macOS unified logging.

Stream logs:
```
log stream --predicate 'process == "DevCam"' --style compact
```

Show recent logs:
```
log show --last 1h --predicate 'process == "DevCam"' --style compact
```

### Instruments
Use Instruments to profile performance:
1. Product > Profile (Cmd-I)
2. Choose a template:
   - Time Profiler
   - Allocations
   - Leaks
   - GPU

Expected metrics:
- CPU: 3 to 5 percent during recording
- Memory: about 150 to 200 MB
- GPU: encoder active

## Common Build Errors

### Error: DevCam has not been granted screen recording permission
Solution: grant permission in System Settings > Privacy and Security > Screen Recording

### Error: Code signing failed
Solution:
1. Ensure Automatically manage signing is enabled
2. Verify a valid Apple ID is logged in
3. Check internet connection for profile download

### Error: Cannot find SCStream in scope
Solution: set deployment target to macOS 13.0 or later

### Error: Missing entitlement
Solution: add required entitlement to DevCam.entitlements

## Performance Profiling

### CPU Usage
1. Run Instruments > Time Profiler
2. Record for 5 minutes
3. Target: under 3 percent average CPU

### Memory Usage
1. Run Instruments > Allocations
2. Monitor for 30 minutes
3. Target: stable 150 to 200 MB

### Disk I/O
1. Run Instruments > File Activity
2. Record segment rotation
3. Verify writes every 60 seconds and deletion of oldest segment

## Distribution

### Notarization
macOS 10.15+ requires notarization for distribution outside the App Store.

```
xcrun notarytool submit DevCam.dmg \
  --apple-id your@email.com \
  --team-id TEAM_ID \
  --password @keychain:AC_PASSWORD

xcrun stapler staple DevCam.dmg
```

### Create DMG

```
hdiutil create -volname DevCam \
  -srcfolder DevCam.app \
  -ov -format UDZO \
  DevCam.dmg
```

## Continuous Integration (Optional)

Example GitHub Actions workflow:
```
name: Build and Test

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: xcodebuild build -scheme DevCam
      - name: Test
        run: xcodebuild test -scheme DevCam -destination 'platform=macOS'
```

## Troubleshooting

### Clean Build
1. Product > Clean Build Folder (Cmd-Shift-K)
2. Delete DerivedData:
```
rm -rf ~/Library/Developer/Xcode/DerivedData/DevCam-*
```

### Reset Permissions
```
tccutil reset ScreenCapture Jonathan-Hines-Dumitru.DevCam
```

## Getting Help
- Build issues: open a GitHub issue (coming soon)
- Xcode problems: Apple Developer Forums
- ScreenCaptureKit notes: docs/SCREENCAPTUREKIT.md
