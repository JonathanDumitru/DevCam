# Current State Snapshot (Updated 2026-01-31, v1.2.2)

## Summary
- Continuous recording is stable with a 15-minute rolling buffer and retroactive export.
- Menubar save workflow supports 1-15 minute exports (1-minute steps) plus advanced custom ranges.
- Recording quality selection is implemented (Low/Medium/High); changes apply after restart.
- Display selection is implemented with safe switching (buffer clears on switch).
- Adaptive quality and battery-aware recording modes are implemented (apply after restart).
- Health dashboard shows session/lifetime stats, disk usage, and recent errors.
- Launch at Login fully functional using ServiceManagement framework (macOS 13.0+).
- Keyboard shortcuts (⌘⌥5/6/7) available for quick clip saving.
- Save location and notifications apply immediately without restart.
- Performance remains low during recording; brief energy spikes occur when revealing files (expected macOS behavior).

## Observed Behavior
- Recording starts automatically and maintains a rolling 15-minute buffer.
- Save actions are enabled once buffer time accumulates.
- Menubar reports recording state, buffer duration, and export progress.
- Keyboard shortcuts (⌘⌥5/6/7) save 5/10/15 minute clips via the global shortcut handler.

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
- Energy impact is low on average; brief spike when revealing files (Finder activation).

## Minimum Performance Target (M1)
- CPU average <= 5% during steady recording; peak <= 8% during UI actions.
- Memory <= 150 MB during a 15-minute run.
- Energy impact low on average; brief spikes allowed for Preferences and file actions.
- Disk activity minimal during steady recording; temporary spikes during export/buffer rotation.

## In Progress
- Evaluating performance impacts across Low/Medium/High recording quality.

## Prior Incidents (Resolved)
- AVAssetWriterInput output settings crash fixed by nesting compression properties.
- `incident-logs/DevCam-2026-01-23-075747.ips`
- `incident-logs/DevCam-2026-01-23-080819.ips`
- `incident-logs/DevCam-2026-01-23-100353.ips`
- `incident-logs/DevCam-2026-01-23-102332.txt`
- `incident-logs/DevCam-2026-01-23-104322.txt`
- `incident-logs/DevCam-2026-01-23-104842.txt`

## Recently Resolved Issues (2026-01-26)
### Console Log Spam
- **Status**: RESOLVED
- **Impact**: Console filled with ~3600 "Sample buffer has no image buffer" messages per minute during recording
- **Root Cause**: ScreenCaptureKit sends metadata frames (cursor updates, window notifications) without pixel buffers; every frame logged a warning
- **Fix**: Implemented rate-limited logging (once per 60 seconds) in `RecordingManager.swift:356-360`
- **Verification**: Console output now clean during normal operation, occasional debug messages at reasonable intervals

### Debug Print Cleanup
- **Status**: COMPLETED
- **Impact**: 145 print() statements cluttering console during normal operation
- **Fix**: Removed all print() statements and replaced with proper DevCamLogger calls where appropriate
- **Files Modified**: RecordingManager.swift (49), DevCamApp.swift (69), PermissionManager.swift (9), BufferManager.swift (6), AppSettings.swift (4), MenuBarView.swift (5), AdvancedClipWindow.swift (3)

### Preferences Window Energy Spikes
- **Status**: RESOLVED
- **Impact**: Energy spike visible in Activity Monitor when opening Preferences window
- **Root Cause**: Window and popover were destroyed and recreated on every open, causing unnecessary NSWindow/NSHostingView allocation
- **Fix**: Reuse existing window/popover instead of recreating; show with `makeKeyAndOrderFront`
- **Files Modified**: `DevCamApp.swift:showPreferences(), statusItemClicked()`

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
