# DevCam Diagnostics

Use this guide to collect useful information for beta reports.

## Logs
Console.app:
- Open Console.app and filter for "DevCam".

Terminal:
```
log show --last 10m --predicate 'process == "DevCam"' --style compact
```

## Buffer and Clip Locations
- Rolling buffer:
  - `~/Library/Application Support/DevCam/buffer/`
- Saved clips (default):
  - `~/Movies/DevCam/`
- Preferences:
  - `~/Library/Preferences/Jonathan-Hines-Dumitru.DevCam.plist`

## Check Disk Space
```
df -h ~
```

## Verify Buffer Segments
```
ls -lh ~/Library/Application\ Support/DevCam/buffer/
```

## Permissions
- System Settings -> Privacy & Security -> Screen Recording

## Optional: Reset Buffer (Deletes Unsaved History)
If asked to reset, quit DevCam and delete buffer files:
```
rm -rf ~/Library/Application\ Support/DevCam/buffer/*
```
Warning: This removes unsaved buffer history.
