# Troubleshooting

Status: Items marked (Planned) refer to features not yet available in current builds.

## No menubar icon
- Ensure the app is running (Activity Monitor).
- Relaunch DevCam.
- On macOS Ventura and later, check the menu bar overflow area.

## Permission denied (Planned)
- Open System Settings > Privacy and Security > Screen Recording.
- Enable DevCam and relaunch the app.
- If permission still appears missing, reboot and try again.

## Recording shows black screen (Planned)
- Confirm Screen Recording permission is granted.
- Quit and relaunch DevCam after changing permission.
- Test with a single display to isolate multi-display issues.

## Clips not saving (Planned)
- Verify the save location is writable.
- Check disk space (at least 2 GB recommended).
- Make sure the buffer has enough history for the requested duration.
- Review logs in Console.app (filter for "DevCam") or use `log show`.

## Export fails or is corrupted (Planned)
- Try a shorter export duration.
- Restart recording to regenerate the buffer.
- Confirm the buffer directory exists and is writable.
- Avoid exporting while disk space is low.

## High CPU usage (Planned)
- Close GPU-heavy applications.
- Reduce display resolution if possible.
- Pause recording if you are not actively using DevCam.

## Multi-display issues (Planned)
- Disconnect and reconnect external displays.
- Relaunch DevCam to re-enumerate displays.
- If a specific display is needed, check the Recording settings.

## App does not start recording (Planned)
- Confirm permission in System Settings.
- If permission is granted, toggle recording off and on.
- Check logs for errors and include them in support requests.

## Recording shows Paused, clips disabled, or Preferences hangs
- Confirm Screen Recording permission is granted in System Settings.
- Check Console.app for DevCam logs and crash reports.
- If you see `Output settings dictionary contains one or more invalid keys`, attach the log and any `.ips` report to your issue.
- Include hardware model, macOS version, and display setup in the report.

## Console log spam: "Sample buffer has no image buffer"
- This message can appear repeatedly during capture.
- Capture a short log snippet (10-30 seconds) and include it with your report.
- Note whether Picture-in-Picture or other overlays were active.

## Energy impact spikes during Preferences or file actions
- Brief spikes are expected when opening Preferences or revealing/exporting clips.
- If spikes persist, capture a short Activity Monitor sample and include it with your report.

## Where to get help
- See SUPPORT.md for issue reporting guidance.
