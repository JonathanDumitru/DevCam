# DevCam Compatibility Guide

## Supported macOS
- macOS 13.0+ (ScreenCaptureKit and ServiceManagement)

## Hardware
- Apple Silicon: supported
- Intel Macs: supported (performance may vary)

## Displays
- Primary display recording (largest resolution) is supported.
- Specific display selection is supported in Preferences and the menubar.
- All-displays mode is not implemented and falls back to primary.
- High-resolution displays (4K and above) increase CPU, GPU, and disk usage.

## Performance Expectations (Baseline)
Based on the current target profile (M1, 1080p, 60fps, 15-minute buffer):
- CPU average <= 5% during steady recording (peaks <= 8% during UI actions)
- Memory <= 150 MB
- Energy impact low on average; brief spikes acceptable during UI actions

## Not Yet Validated (Report Results)
- Extended 4K/5K capture sessions
- More than two external displays
- Long-running sessions (> 4 hours)
- Intel Macs with integrated graphics under heavy GPU load

## Known Behavior
- Shortcuts are system-wide but do not consume the keystroke.
- Save location and notification settings apply immediately.
- Recording quality and battery monitoring changes require restart.
- Exported clips are currently video-only even if audio capture is enabled.

## Report Compatibility Issues
Use `docs/FEEDBACK_TEMPLATE.md` and include your hardware and display details.
