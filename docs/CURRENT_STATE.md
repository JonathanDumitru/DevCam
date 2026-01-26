# Current State Snapshot (Updated 2026-01-26, v1.2.1)

## Summary
- Continuous recording is stable with a 15-minute rolling buffer and retroactive export.
- Menubar save workflow supports 1-15 minute exports (1-minute steps) plus advanced custom ranges.
- Recording quality selection is implemented (Low/Medium/High); changes apply after restart.
- Launch at Login fully functional using ServiceManagement framework (macOS 13.0+).
- Performance remains low during recording; brief energy spikes occur when opening Preferences or revealing files.
- Console log spam observed: "Sample buffer has no image buffer" (mitigation in progress).

## Observed Behavior
- Recording starts automatically and maintains a rolling 15-minute buffer.
- Save actions are enabled once buffer time accumulates.
- Menubar reports recording state, buffer duration, and export progress.
- Keyboard shortcuts save fixed 5/10/15 minute clips when DevCam is active.

## Evidence
- Recent test notes provided via console logs and Activity Monitor during the 15-minute run.

## Test Context
- User scenario: Apple TV in Picture-in-Picture over Console.app.
- Screen recording permission reported as granted.
- Single display detected at 1920x1080.

## Impact
- CPU averages ~4% (peaks ~6%).
- Memory stays under ~100 MB.
- Disk activity remains under ~1 MB during steady-state observation.
- Energy impact is low on average, with spikes when opening Preferences or revealing files.

## Minimum Performance Target (M1)
- CPU average <= 5% during steady recording; peak <= 8% during UI actions.
- Memory <= 150 MB during a 15-minute run.
- Energy impact low on average; brief spikes allowed for Preferences and file actions.
- Disk activity minimal during steady recording; temporary spikes during export/buffer rotation.

## In Progress
- Investigating and reducing "Sample buffer has no image buffer" log spam.
- Evaluating performance impacts across Low/Medium/High recording quality.

## Prior Incidents (Resolved)
- AVAssetWriterInput output settings crash fixed by nesting compression properties.
- `incident-logs/DevCam-2026-01-23-075747.ips`
- `incident-logs/DevCam-2026-01-23-080819.ips`
- `incident-logs/DevCam-2026-01-23-100353.ips`
- `incident-logs/DevCam-2026-01-23-102332.txt`
- `incident-logs/DevCam-2026-01-23-104322.txt`
- `incident-logs/DevCam-2026-01-23-104842.txt`

## Recently Resolved Critical Bugs (2026-01-25)
### Bug #1: Menubar Icon Not Visible
- **Status**: RESOLVED
- **Impact**: App appeared non-functional - users couldn't access menubar controls
- **Root Cause**: Configuration conflict between `LSUIElement=true` (Info.plist) and `NSApp.setActivationPolicy(.accessory)` (programmatic) caused macOS to hide ALL UI including menubar icon
- **Fix**: Removed redundant programmatic activation policy call in `DevCamApp.swift:72-77`
- **Verification**: Menubar icon now visible immediately on launch, menu functional, no Dock icon present

### Bug #2: Intermittent Zero-Byte Video Segments
- **Status**: RESOLVED
- **Impact**: ~5% of video segments (4 out of 77 observed) were 0-byte empty files, causing gaps in recordings
- **Root Cause**: AVAssetWriter race condition where `finishWriting()` called before `startWriting()` when ScreenCaptureKit delivered only metadata frames (no pixel buffers) in first 60 seconds of segment
- **Fix**: Start AVAssetWriter immediately in `startNewSegment()` with `atSourceTime: .zero`, eliminating conditional start logic in `processSampleBuffer()`
- **Verification**: 19 consecutive segments created with 0% failure rate, all segments 69MB-120MB (valid sizes), diagnostic logging added to detect future occurrences
- **Files Modified**: `RecordingManager.swift:313-328, 357-368, 404-414`
- **Performance**: No impact - CPU 10.1%, Memory 81.2 MB during 8+ minute test run

## Open Questions / Missing Info
- macOS version, hardware model (Intel/Apple Silicon), and display setup.
- Whether log spam persists without Picture-in-Picture or at lower resolutions.
- Whether energy spikes improve with a lower resolution selection.

## Related Docs
- `incident-logs/2026-01-23-incident.md`
- `docs/TROUBLESHOOTING.md`
