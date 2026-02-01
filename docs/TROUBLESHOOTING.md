# Troubleshooting

Status: This guide reflects current beta behavior; some sections note limitations.

## No menubar icon
**Note**: This issue was fixed in build 2026-01-25. If using an earlier build, update to the latest version.

- Ensure the app is running (Activity Monitor).
- Relaunch DevCam.
- On macOS Ventura and later, check the menu bar overflow area.
- If using a build before 2026-01-25, the menubar icon may be hidden due to a configuration conflict (fixed in latest version).

## Permission denied
- Open System Settings > Privacy and Security > Screen Recording.
- Enable DevCam and relaunch the app.
- If permission still appears missing, reboot and try again.

## Recording shows black screen
- Confirm Screen Recording permission is granted.
- Quit and relaunch DevCam after changing permission.
- Test with a single display to isolate multi-display issues.

## Clips not saving
- Verify the save location is writable.
- Check disk space (at least 2 GB recommended).
- Make sure the buffer has enough history for the requested duration.
- Review logs in Console.app (filter for "DevCam") or use `log show`.

## Export fails or is corrupted
- Try a shorter export duration.
- Restart recording to regenerate the buffer.
- Confirm the buffer directory exists and is writable.
- Avoid exporting while disk space is low.

## Zero-byte or missing segment files
**Note**: This issue was fixed in build 2026-01-25. If using an earlier build, update to the latest version.

- **Before 2026-01-25**: Intermittent issue (~5% of segments) where video segment files were created with 0 bytes
- **Cause**: Race condition in AVAssetWriter when only metadata frames arrived before segment rotation
- **Fix**: Writer now starts immediately on segment creation, eliminating the race condition
- **If you see this in logs**: Check your DevCam build date and update to latest version
- **Verification**: Check buffer directory `~/Library/Application Support/DevCam/buffer/` for 0-byte .mp4 files using `ls -lh`

## High CPU usage
- Close GPU-heavy applications.
- Reduce display resolution if possible.
- Switch to a lower recording quality in Preferences and restart DevCam.

## Multi-display issues
- Disconnect and reconnect external displays.
- Relaunch DevCam to re-enumerate displays.
- If a specific display is needed, check the Recording settings.

## App does not start recording
- Confirm permission in System Settings.
- If permission is granted, quit and relaunch DevCam.
- Check logs for errors and include them in support requests.

## Shortcuts do not work
- Shortcuts are system-wide: Command-Option-5/6/7.
- Global monitors do not consume events, so the active app still receives the keystroke.
- If a shortcut conflicts with another app, use the menubar Save Clip slider instead.

## Quality or save location changes do not apply
- Recording quality changes require restart.
- Save location and notifications apply immediately for new exports.
- Battery mode changes require restart.

## Recording shows Paused, clips disabled, or Preferences hangs
- Confirm Screen Recording permission is granted in System Settings.
- Check Console.app for DevCam logs and crash reports.
- If you see `Output settings dictionary contains one or more invalid keys`, attach the log and any `.ips` report to your issue.
- Include hardware model, macOS version, and display setup in the report.

## Console log spam: "Sample buffer has no image buffer"
- This was rate-limited in builds after 2026-01-26.
- If you still see rapid repeats, capture a short log snippet (10-30 seconds) and include it with your report.
- Note whether Picture-in-Picture or other overlays were active.

## Energy impact spikes during Preferences or file actions
- Brief spikes are expected when opening Preferences or revealing/exporting clips.
- If spikes persist, capture a short Activity Monitor sample and include it with your report.

## Launch at Login not working

**Symptoms:**
- Toggle in Preferences appears on but app doesn't launch at login
- Error message when trying to enable launch at login
- DevCam missing from System Settings > General > Login Items

**Solutions:**

1. **Check System Settings manually:**
   - Open System Settings > General > Login Items
   - Verify DevCam appears in the list
   - If missing, try toggling the Preferences setting again

2. **Permission or security restrictions:**
   - Some enterprise or school-managed Macs restrict login items
   - Check with your IT administrator if settings don't persist

3. **Manually add to Login Items:**
   - Open System Settings > General > Login Items
   - Click the "+" button under "Open at Login"
   - Navigate to Applications and select DevCam.app
   - Note: Manual additions may not sync with DevCam's toggle

4. **State desync:**
   - If DevCam shows enabled but System Settings shows disabled (or vice versa):
   - Quit DevCam completely
   - Relaunch DevCam (it will sync state on startup)
   - Toggle the setting to refresh

5. **Check Console logs:**
   - Filter for "DevCam" and "launch at login" messages
   - Look for ServiceManagement errors
   - Include relevant logs in support requests

**Requirements:**
- macOS 13.0 (Ventura) or later is required for Launch at Login functionality
- Older macOS versions will show the toggle but it won't function

## Where to get help
- See SUPPORT.md for issue reporting guidance.
