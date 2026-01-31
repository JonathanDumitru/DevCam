# DevCam Compatibility Guide

## Supported macOS
- macOS 13.0+ (ScreenCaptureKit required; launch at login uses SMAppService)

## Hardware
- Apple Silicon: supported
- Intel Macs: supported (performance may vary)

## Displays
- Records the primary display (largest resolution).
- Multi-display is supported by ScreenCaptureKit, but DevCam does not yet allow
  manual display selection.
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
- Shortcuts are reliable when DevCam is active (Cmd-Option-5/6/7).
- Save location and notifications apply immediately; recording quality changes apply after restart.

## Report Compatibility Issues
Use `docs/FEEDBACK_TEMPLATE.md` and include your hardware and display details.
