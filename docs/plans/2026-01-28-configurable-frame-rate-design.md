# Design: Configurable Frame Rate with Auto-Adjustment

**Date:** 2026-01-28
**Status:** Approved
**Author:** Brainstorming session

## Summary

A frame rate control system that lets users choose a target frame rate (10/15/30/60 fps) and optionally auto-reduces frame rate during idle periods using hybrid detection: input-based idle tracking plus frame comparison during transitions.

## Motivation

The current 60 fps capture rate causes high CPU usage, which is overkill for typical development work where the screen changes infrequently. Allowing lower frame rates and intelligent auto-adjustment reduces CPU load while maintaining quality when it matters.

## User-Facing Settings

New preferences in Recording tab:

- **Frame Rate** picker: 10, 15, 30, 60 fps (default: 30)
- **Adaptive Frame Rate** toggle (default: off)
  - When enabled, shows sub-options:
  - **Idle threshold**: seconds of no input before reducing (default: 5s)
  - **Idle frame rate**: what to drop to during idle (default: 10 fps)

### Rationale

- 30 fps default balances quality and CPU (vs current 60)
- Keeping adaptive off by default avoids surprising users
- 5-second idle threshold catches natural pauses without being too aggressive

## Idle Detection System

### Hybrid Detection Logic

1. **Input monitoring** (primary signal)
   - Track last mouse move and keystroke timestamps via `NSEvent.addGlobalMonitorForEvents`
   - When `timeSinceLastInput > idleThreshold`: enter "potentially idle" state

2. **Frame comparison** (confirmation during transitions)
   - Only runs when transitioning between active ↔ idle states
   - Compare current frame to previous using downsampled pixel comparison
   - If frames differ significantly: stay at active frame rate
   - If frames match: confirm idle, reduce frame rate

3. **State machine:**
   ```
   Active (target fps)
       → [no input for 5s] → PendingIdle (compare frames)
           → [frames static] → Idle (idle fps)
           → [frames changing] → Active

   Idle (idle fps)
       → [any input] → Active (immediate)
       → [frame change detected] → Active
   ```

### Why Hybrid

- Pure input-based misses videos/animations playing without user input
- Pure frame-based adds constant CPU overhead
- Hybrid only compares frames during state transitions (~twice per idle cycle)

## Implementation Components

### New Files

1. **`InputActivityMonitor.swift`** (~80 lines)
   - Singleton that tracks mouse/keyboard events
   - Exposes `timeSinceLastInput: TimeInterval`
   - Uses `NSEvent.addGlobalMonitorForEvents` (requires Accessibility permission check)

2. **`FrameRateController.swift`** (~120 lines)
   - Owns the state machine (Active/PendingIdle/Idle)
   - Subscribes to InputActivityMonitor
   - Performs frame comparison during transitions
   - Publishes `currentFrameRate: Int` for RecordingManager to consume

### Modified Files

3. **`AppSettings.swift`** - Add new properties:
   - `targetFrameRate: Int` (10/15/30/60, default 30)
   - `adaptiveFrameRateEnabled: Bool` (default false)
   - `idleThreshold: TimeInterval` (default 5.0)
   - `idleFrameRate: Int` (default 10)

4. **`RecordingManager.swift`** - Changes:
   - Use `settings.targetFrameRate` in stream config instead of hardcoded 60
   - Subscribe to `FrameRateController.currentFrameRate` when adaptive is enabled
   - Call `SCStream.updateConfiguration()` when frame rate changes

5. **`RecordingTab.swift`** - Add UI for new settings

## Frame Comparison Strategy

For transition-time frame comparison, use downsampled pixel comparison:

1. **Downsample aggressively** - Resize frame to 32x32 pixels (1024 pixels total)
2. **Convert to grayscale** - Reduces comparison to single channel
3. **Compare pixel deltas** - Sum absolute differences between frames
4. **Threshold** - If total delta < 5% of max possible difference, frames are "static"

### Why This Approach

- Simpler to implement with CoreGraphics (no external dependencies)
- 32x32 grayscale comparison is ~1KB of data, trivial CPU cost
- Perceptual hashing (pHash) requires DCT transforms, overkill for our needs

### When Comparison Runs

- Only during `Active → PendingIdle` transition (once per idle cycle)
- During `Idle` state: sample every 2 seconds to detect video playback starting
- Never during active recording - no overhead when user is working

### Frame Sampling

- Grab reference frame when entering PendingIdle
- Compare against next frame 500ms later
- Two matching frames = confirm idle

## Error Handling & Edge Cases

### Permission Handling

- Input monitoring requires Accessibility permission on macOS
- If permission denied: adaptive frame rate silently disabled, use static target rate
- Show subtle indicator in Health tab if adaptive is enabled but permission missing

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Video playing, no user input | Frame comparison detects motion, stays at active rate |
| User moves mouse during PendingIdle | Immediate return to Active, skip frame comparison |
| Screen saver activates | Recording pauses anyway (existing behavior), no impact |
| External display connected/disconnected | Stream restarts (existing), frame rate controller resets to Active |
| App launch with adaptive enabled | Start in Active state, begin idle detection after 1s warmup |

### Rate Limiting

- `SCStream.updateConfiguration()` is lightweight but avoid thrashing
- Minimum 2 seconds between frame rate changes
- If user becomes active during ramp-down, cancel immediately (no delay)

### Logging

- Debug log frame rate transitions for troubleshooting
- Include in Health tab stats: "Frame rate: 30 fps (idle: 10 fps)"

## Testing Strategy

### Unit Tests

1. **FrameRateController state machine**
   - Active → PendingIdle after idle threshold
   - PendingIdle → Idle when frames match
   - PendingIdle → Active when frames differ
   - Any state → Active on input

2. **Frame comparison**
   - Identical frames return "static"
   - Different frames return "changed"
   - Threshold boundary cases

### Integration Tests

3. **Settings persistence**
   - Frame rate values save/restore correctly
   - Adaptive toggle persists

4. **RecordingManager integration**
   - Stream config uses correct frame rate on start
   - Frame rate changes apply via updateConfiguration()

### Manual Testing Checklist

- [ ] Record at each frame rate (10/15/30/60), verify playback smoothness
- [ ] Enable adaptive, go idle, confirm CPU drops
- [ ] Play a YouTube video while idle, confirm rate stays high
- [ ] Rapid mouse movement during PendingIdle, confirm quick recovery
- [ ] Deny Accessibility permission, confirm graceful fallback

## Implementation Order

1. Add settings to AppSettings.swift and RecordingTab.swift
2. Update RecordingManager to use configurable frame rate (static)
3. Implement InputActivityMonitor
4. Implement FrameRateController with state machine
5. Integrate adaptive frame rate with RecordingManager
6. Add frame comparison logic
7. Add Health tab indicators
8. Write tests
