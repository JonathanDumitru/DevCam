# DevCam UX Improvements Design

## Summary

Three UX enhancements to improve the developer experience:

1. **Global Keyboard Shortcuts** - Customizable hotkeys for clip export and pause/resume
2. **Dynamic Menubar Icon** - Visual feedback showing recording state, buffer level, and activity
3. **Quick Preview with Trim** - Preview clips before export with trim controls

## 1. Global Keyboard Shortcuts

### Architecture

```
ShortcutManager (new)
├── Registers global hotkeys via MASShortcut or Carbon APIs
├── Stores user-configured key combinations
├── Routes actions to RecordingManager/ClipExporter
└── Handles permission requirements (Accessibility)
```

### Shortcut Actions

| Action | Default Shortcut | Configurable |
|--------|------------------|--------------|
| Export Last 30s | ⌘⇧S | Yes |
| Export Last 1m | ⌘⇧M | Yes |
| Export Last 5m | ⌘⇧L | Yes |
| Pause/Resume | ⌘⇧P | Yes |

### Data Model

```swift
struct ShortcutConfig: Codable {
    let action: ShortcutAction
    var keyCode: UInt16
    var modifierFlags: NSEvent.ModifierFlags
    var isEnabled: Bool
}

enum ShortcutAction: String, CaseIterable, Codable {
    case exportLast30Seconds
    case exportLast1Minute
    case exportLast5Minutes
    case togglePauseResume
}
```

### Settings UI

- List of shortcut actions with current binding
- Click-to-record interface for customization
- Clear button to remove binding
- Reset to defaults option

## 2. Dynamic Menubar Icon

### Visual States

| State | Icon | Badge | Animation |
|-------|------|-------|-----------|
| Recording | Filled circle | Buffer minutes | Subtle pulse |
| Paused | Hollow circle | Buffer minutes | None |
| Idle/Stopped | Hollow circle | None | None |
| Error | Exclamation | None | None |
| Exporting | Arrow up | Progress % | None |

### Badge Design

- Small numeric badge showing buffered minutes (e.g., "12")
- Positioned bottom-right of icon
- Updates every 30 seconds during recording
- Hidden when buffer is empty

### Implementation

```swift
class MenubarIconManager: ObservableObject {
    @Published var currentState: RecordingState
    @Published var bufferMinutes: Int
    @Published var exportProgress: Double?

    func updateIcon() {
        // Render appropriate SF Symbol + badge
        // Use NSImage with canvas drawing for badge
    }
}
```

### Animation

- Recording state: gentle pulse animation (opacity 0.7-1.0, 2s cycle)
- Implemented via Timer-based opacity changes
- Respects system "Reduce Motion" accessibility setting

## 3. Quick Preview with Trim Controls

### Window Design

```
┌─────────────────────────────────────────┐
│ Preview                           ✕     │
├─────────────────────────────────────────┤
│                                         │
│           [Video Player]                │
│              640x360                    │
│                                         │
├─────────────────────────────────────────┤
│  ◀──────[====TRIM====]──────▶          │
│  0:00                           2:30    │
├─────────────────────────────────────────┤
│  Selected: 0:45 - 1:30 (0:45)          │
│                                         │
│     [Cancel]           [Export Clip]    │
└─────────────────────────────────────────┘
```

### Components

**VideoPreviewView**
- AVPlayerView for playback
- Scrubbing via click/drag on timeline
- Play/pause toggle

**TrimSliderView**
- Dual-handle range slider
- Visual waveform/thumbnail strip (stretch goal)
- Snapping to segment boundaries optional

**PreviewWindowController**
- Manages preview lifecycle
- Coordinates between player and trim controls
- Handles export action with trimmed range

### Data Flow

```
User triggers preview
  → ClipExporter.preparePreview(duration:)
  → Create temporary composition
  → Open PreviewWindow with AVPlayer
  → User adjusts trim handles
  → User clicks Export
  → ClipExporter.exportClip(composition:, range:)
  → Save to user's export folder
```

## 4. Implementation Components

### New Files

| File | Purpose |
|------|---------|
| `Core/ShortcutManager.swift` | Global hotkey registration and dispatch |
| `Core/MenubarIconManager.swift` | Dynamic icon rendering and state |
| `UI/ShortcutsTab.swift` | Shortcuts preferences UI |
| `UI/ShortcutRecorderView.swift` | Click-to-record shortcut capture |
| `UI/PreviewWindow.swift` | Preview window with player and trim |
| `UI/TrimSliderView.swift` | Dual-handle trim control |
| `UI/VideoPreviewView.swift` | AVPlayer wrapper for preview |

### Modified Files

| File | Changes |
|------|---------|
| `AppSettings.swift` | Add shortcut storage |
| `AppDelegate.swift` | Initialize ShortcutManager |
| `MenuBarView.swift` | Integrate MenubarIconManager |
| `ClipExporter.swift` | Add preparePreview(), exportWithRange() |
| `PreferencesView.swift` | Add Shortcuts tab |

## 5. Error Handling

### Shortcuts

- **No Accessibility permission**: Show alert with button to open System Preferences
- **Conflicting shortcut**: Warn user, offer to override or cancel
- **System shortcut conflict**: Inform user the combination is reserved

### Preview

- **Corrupt segment**: Skip in preview, show warning badge
- **Insufficient buffer**: Disable preview button, show tooltip
- **Export failure**: Keep preview open, show error, allow retry

### Menubar Icon

- **Render failure**: Fall back to static default icon
- **State sync issue**: Re-query RecordingManager on timer

## 6. Testing Strategy

### Unit Tests

- ShortcutManager: Registration, conflict detection, persistence
- MenubarIconManager: State transitions, badge formatting
- TrimSliderView: Range validation, boundary snapping

### Integration Tests

- End-to-end: Hotkey → Export → File saved
- Preview: Open → Trim → Export → Verify duration matches

### Manual Testing

- Verify shortcuts work when app is in background
- Test with multiple displays
- Verify menubar icon updates smoothly
- Test trim precision at segment boundaries
