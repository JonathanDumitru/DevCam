# Window Capture Design

## Summary

Add window-specific capture with picture-in-picture layout, live switching, and seamless fallback to display capture.

## Core Concept

- **Click-to-select overlay** - Click windows on screen to select them; first click = primary (large), subsequent = secondary (PiP corners)
- **Auto-arrange PiP** - System positions secondary windows automatically based on count and size
- **Live switching** - Add/remove windows without interrupting recording buffer
- **Soft limit** - Warning after 4 windows that performance/quality may degrade
- **Fallback** - If all windows close, falls back to display capture automatically
- **Unified toggle** - Switch between display/window mode from menubar

## User Interface

### Menubar Dropdown

```
┌─────────────────────────────────┐
│ ● Recording                     │
│ Buffer: 12:30 / 15:00           │
├─────────────────────────────────┤
│ Capture Mode:                   │
│   ○ Display (current)           │
│   ● Windows (3 selected)        │
│                                 │
│   [Select Windows...]     ⌘⇧W  │
├─────────────────────────────────┤
│ Save Clip                       │
│ ...                             │
└─────────────────────────────────┘
```

### Click-to-Select Overlay

- Dims the screen, highlights window boundaries
- Click a window → green border + checkmark (selected)
- First selected window shows "PRIMARY" badge
- Click selected window again → deselects it
- ⌘+click any selected window → reassign as primary
- Shows count: "3 windows selected (⚠️ 5+ may affect quality)"
- Press Escape or click "Done" button to confirm

### Keyboard Shortcut

- ⌘⇧W (default) opens the overlay
- Configurable in the existing Shortcuts preferences tab

## Technical Architecture

### New Components

| Component | Purpose |
|-----------|---------|
| `WindowCaptureManager` | Manages SCWindow capture streams, handles window lifecycle |
| `WindowCompositor` | Combines multiple window frames into single PiP output |
| `WindowSelectionOverlay` | Full-screen NSWindow for click-to-select UI |
| `CaptureMode` enum | `.display` or `.windows([WindowSelection])` |

### Data Model

```swift
enum CaptureMode: Codable {
    case display
    case windows
}

struct WindowSelection: Codable, Identifiable {
    let windowID: CGWindowID
    let appName: String
    let windowTitle: String
    var isPrimary: Bool

    var id: CGWindowID { windowID }
}
```

### Integration Points

- `RecordingManager` - Add `captureMode` property, handle mode switching without buffer interruption
- `AppSettings` - Store capture mode preference and default shortcut
- `MenuBarView` - Add capture mode toggle and "Select Windows..." button
- `ShortcutManager` - Register ⌘⇧W for overlay trigger

### Live Switching Strategy

When windows change mid-recording:
1. Keep existing AVAssetWriter running
2. Update SCStream configuration with new window list
3. WindowCompositor adjusts layout for next frame
4. No segment break needed

## PiP Layout & Compositing

### Auto-Arrange Algorithm

| Windows | Layout |
|---------|--------|
| 1 (primary only) | Full frame |
| 1 + 1 secondary | Primary full, secondary bottom-right corner (25% size) |
| 1 + 2 secondary | Primary full, secondaries bottom-right and bottom-left |
| 1 + 3 secondary | Primary full, secondaries in three corners (top-right empty for menubar) |
| 1 + 4+ secondary | Same as 3, additional windows cycle through corners (stacked) |

### Secondary Window Sizing

- Base size: 25% of output frame width
- Aspect ratio preserved from source window
- 8px padding from edges
- 4px gap between stacked windows in same corner

### Quality Preservation

- Primary window rendered at full output resolution
- Secondary windows captured at native size, scaled down for PiP
- No quality loss on primary content
- Output resolution matches user's quality setting (720p/1080p/native)

## Window Lifecycle & Edge Cases

### Window Closed/Minimized

- Window auto-removed from capture list
- Layout reflows immediately (e.g., 3 → 2 windows)
- If primary closes, first secondary promotes to primary
- Menubar badge updates: "2 windows"

### All Windows Closed

- Automatic fallback to display capture
- Menubar shows: "Windows → Display (fallback)"
- When user selects new windows, switches back to window mode
- No buffer interruption during fallback

### Window Restored/Reopened

- Not auto-re-added (user must select again)
- Prevents unexpected windows appearing in recording

### App-Specific Behaviors

- Windows with "windowLevel" above normal (e.g., tooltips, menus) excluded from picker
- Full-screen apps captured correctly via SCWindow
- Spaces/desktops: only windows on current space shown in picker

### Soft Limit Warning

- After 4 windows: yellow indicator "⚠️ 5 windows - quality may degrade"
- After 6 windows: orange indicator "⚠️ 7 windows - consider reducing"
- Warning shown in overlay and menubar tooltip

## Error Handling

### Capture Failures

| Scenario | Response |
|----------|----------|
| SCStream fails for one window | Remove from capture, log warning, continue with remaining windows |
| SCStream fails for all windows | Fall back to display capture, show error badge on menubar icon |
| Compositor frame drop | Skip frame, maintain timing, log for health stats |

### Performance Degradation

- Monitor frame rate during multi-window capture
- If FPS drops below 50% of target for 10+ seconds:
  - Show notification: "Recording quality reduced - consider fewer windows"
  - Log to HealthStats for diagnostics

### Recovery

- If window capture repeatedly fails, offer "Switch to Display Capture" in menubar
- User can retry window selection anytime via overlay

## Implementation Phases

### Phase 1: Foundation
- CaptureMode enum and WindowSelection model
- WindowCaptureManager (single window capture, no PiP yet)
- Basic menubar toggle between display/window mode

### Phase 2: Multi-Window & Compositor
- WindowCompositor with auto-arrange PiP layout
- Support for multiple windows (soft limit with warnings)
- Live switching without buffer interruption

### Phase 3: Selection Overlay
- WindowSelectionOverlay (click-to-select UI)
- Primary/secondary designation
- Keyboard shortcut (⌘⇧W)

### Phase 4: Polish & Edge Cases
- Window lifecycle handling (close/minimize/fallback)
- Performance monitoring and warnings
- Unit tests

## Files

### New Files

| File | Purpose |
|------|---------|
| `Core/WindowCaptureManager.swift` | SCWindow stream management, window lifecycle tracking |
| `Core/WindowCompositor.swift` | PiP frame compositing, auto-arrange layout |
| `UI/WindowSelectionOverlay.swift` | Click-to-select full-screen overlay |
| `Models/WindowSelection.swift` | WindowSelection struct, CaptureMode enum |

### Modified Files

| File | Changes |
|------|---------|
| `Core/RecordingManager.swift` | Add captureMode property, integrate WindowCaptureManager |
| `Core/AppSettings.swift` | Add captureMode preference, window selection shortcut |
| `Core/ShortcutManager.swift` | Add `.selectWindows` action (⌘⇧W) |
| `UI/MenuBarView.swift` | Add capture mode toggle, "Select Windows..." button |
| `UI/ShortcutsTab.swift` | Add window selection shortcut to list |
