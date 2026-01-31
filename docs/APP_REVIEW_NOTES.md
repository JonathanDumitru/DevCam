# DevCam App Review Notes (macOS)

Last updated: 2026-01-29

## App Summary
DevCam is a menubar-only macOS app that continuously records the screen into a
rolling 15-minute buffer. Users can retroactively save any portion of the last
15 minutes without having to start recording ahead of time.

## Review Setup
- No account/login required.
- No in-app purchases or subscriptions.
- No network access or external services.
- Permissions used:
  - Screen Recording (required to capture the display)
  - Files (user-selected read/write for save location)
  - Notifications (optional export-complete alerts)

## How to Test
1. Launch DevCam from Applications (menubar icon appears; no Dock icon).
2. Grant Screen Recording permission when prompted.
   - If denied: System Settings -> Privacy & Security -> Screen Recording ->
     enable DevCam, then relaunch.
3. Wait for the buffer timer in the menubar to start incrementing.
4. Save a clip:
   - Menubar menu: set the Save Clip slider (1-15 minutes) and click Save.
   - Keyboard: Cmd+Option+5/6/7 when DevCam is active (popover open).
5. Verify the exported .mp4 appears in the save folder
   (default: ~/Movies/DevCam).
6. Open Preferences -> Privacy to review local-only data handling details.

## Data Handling / Privacy
- No data collection, analytics, tracking, or network traffic.
- All recordings stay local on the user's Mac.
- Privacy policy is provided in App Store Connect (hosted copy of docs/PRIVACY.md).

## Entitlements
- App Sandbox enabled.
- Screen capture entitlement (exception required for App Store submission).
- User-selected file read/write for export location.

## Known Limitations
- No audio recording.
- 15-minute buffer maximum.
- Records the primary display only.
- Shortcuts are only reliable when DevCam is active in sandboxed builds.

## Contact
jonathan@hinesdumitru.online
