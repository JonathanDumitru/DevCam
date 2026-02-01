# DevCam Architecture

This document provides an in-depth look at DevCam's architecture, component
interactions, and design decisions.

Status: RecordingManager, BufferManager, ClipExporter, AppSettings, and the menubar/preferences UI are implemented. Recording quality selection, global shortcuts, launch at login, display selection, adaptive quality, and battery monitoring are wired. All-displays capture and microphone recording remain unimplemented.

## System Overview

DevCam is a native macOS menubar application built with Swift, SwiftUI, and
ScreenCaptureKit. The architecture follows an MVVM-style separation between UI,
recording, buffering, and export workflows.

Note: Diagrams reflect current wiring; some UI settings are stubs (for example, all-displays capture, microphone capture, and shortcut customization).

```
+-------------------------------------------------------------+
|                         MenuBar UI                          |
|                       (SwiftUI Views)                       |
+-------------+-------------------------------+---------------+
              |                               |
              v                               v
+---------------------------+     +---------------------------+
|     RecordingManager      |     |        ClipExporter       |
|                           |     |                           |
| - ScreenCaptureKit        |     | - AVAssetExportSession     |
| - AVAssetWriter           |     | - Segment stitching        |
| - Frame processing        |     | - Progress tracking        |
+-------------+-------------+     +-------------+-------------+
              |                               |
              v                               v
        +---------------------------------------------+
        |      BufferManager (@MainActor class)       |
        |                                             |
        | - Circular buffer (15 segments)            |
        | - Segment metadata                          |
        | - Time range queries                        |
        +---------------------------------------------+
```

## Core Components

### 1. RecordingManager

Purpose: Coordinates ScreenCaptureKit stream and video encoding.

Responsibilities:
- Initialize SCStream with optimal configuration (60fps, H.264, native size)
- Implement SCStreamOutput to receive frame buffers
- Create 1-minute segments using AVAssetWriter
- Rotate segments and register with BufferManager
- Manage recording lifecycle (start, stop, restart)
- Report state changes and errors to the UI

Key properties:
```swift
@Published var isRecording: Bool
@Published var bufferDuration: TimeInterval
@Published var recordingError: Error?

private var stream: SCStream?
private var bufferManager: BufferManager?
private var currentSegmentWriter: AVAssetWriter?
private var segmentTimer: Timer?
```

State transitions:
```
Idle -> Starting -> Recording -> Stopping -> Idle
         |               |
        Error           Paused
```

Performance considerations:
- Hardware-accelerated H.264 encoding (VideoToolbox)
- AVAssetWriter configured with expectsMediaDataInRealTime = true
- Segment rotation occurs asynchronously to avoid UI stalls

### 2. BufferManager (@MainActor class)

Purpose: Thread-safe circular buffer management using segmented video files.

Why @MainActor:
- Keeps buffer state consistent with UI usage
- Simplifies access from recording and export flows

Responsibilities:
- Maintain up to 15 segment metadata entries
- Delete oldest segment when the limit is exceeded
- Track segment timing and duration
- Provide segments for time-range exports
- Manage buffer directory lifecycle

Storage strategy:
- Location: ~/Library/Application Support/DevCam/buffer/
- Segment names: segment_<timestamp>.mp4
- Metadata in-memory; can be rebuilt on launch if needed
- Estimated size: 0.5-2 GB for a full buffer depending on resolution and bitrate

Key methods:
```swift
func addSegment(url: URL, startTime: Date, duration: TimeInterval)
func getSegmentsForTimeRange(duration: TimeInterval) -> [SegmentInfo]
func getCurrentBufferDuration() -> TimeInterval
func clearBuffer()
```

Time-range selection algorithm:
```
1) If requested duration >= available, return all segments
2) Iterate from newest to oldest
3) Collect until accumulated duration >= requested
4) Return in chronological order
```

### 3. ClipExporter

Purpose: Extract and stitch segments into exportable clips.

Responsibilities:
- Query BufferManager for required segments
- Stitch segments using AVMutableComposition
- Export via AVAssetExportSession
- Track export progress and completion
- Save clips to the user-selected folder
- Store recent clip metadata

Export pipeline:
```
User triggers export
  -> BufferManager.getSegmentsForTimeRange
  -> Build AVMutableComposition
  -> AVAssetExportSession.export
  -> Track progress and finalize file
```

File naming:
- DevCam_YYYY-MM-DD_HH-MM-SS.mp4

Progress tracking:
- Poll AVAssetExportSession.progress on a timer (100 ms)
- Publish progress to UI

### 4. AppSettings

Purpose: Centralized user preferences with persistence.

Storage:
- @AppStorage for simple values
- UserDefaults or file-based storage for complex values

Settings schema (logical):
```
saveLocation: URL
launchAtLogin: Bool
showNotifications: Bool
bufferDurationSeconds: Int
recordingQuality: RecordingQuality
shortcuts: [ShortcutAction: KeyboardShortcutConfig]
```

### 5. LaunchAtLoginManager

Purpose: Manages launch at login functionality using macOS ServiceManagement framework.

Implementation:
- Uses `SMAppService.mainApp` (macOS 13.0+) for login item registration
- Eliminates need for separate helper app or launch agent
- Singleton pattern for app-wide access
- Thread-safe operations

Key methods:
```swift
func enable() throws  // Register app as login item
func disable() throws // Unregister app from login items
var isEnabled: Bool   // Query current system state
```

Design rationale:
- **Modern API**: Uses ServiceManagement instead of deprecated LSSharedFileList
- **No helper app**: SMAppService.mainApp registers the main bundle directly
- **System integration**: Appears in System Settings > General > Login Items
- **State sync**: AppSettings checks isEnabled on init to handle manual changes
- **Atomic operations**: Both UserDefaults and system registration succeed or revert together

Error handling:
- Throws on registration/unregistration failures
- AppSettings reverts preference on error
- UI displays alert with guidance to System Settings

## Data Flow Examples

### Scenario 1: User saves last 10 minutes
```
1) User presses hotkey or uses menu
2) AppDelegate routes action to ClipExporter
3) ClipExporter requests segments for 600 seconds
4) BufferManager returns 10 segments
5) ClipExporter builds composition and exports
6) Clip is saved and UI updates
```

### Scenario 2: Segment rotation
```
1) Segment timer fires every 60 seconds
2) RecordingManager finalizes current segment
3) BufferManager adds segment
4) If > 15 segments, delete oldest
5) RecordingManager starts a new segment
```

## Structure Diagrams

The diagrams below show the key types and their relationships. File paths reflect
the intended project layout.

### Class and Protocol Map

```
RecordingManager (DevCam/Core/RecordingManager.swift)
  - conforms to: ObservableObject
  - conforms to: SCStreamOutput
  - conforms to: SCStreamDelegate
  - owns: SCStream, AVAssetWriter, AVAssetWriterInput

BufferManager (DevCam/Core/BufferManager.swift)
  - @MainActor class for segment metadata and disk cleanup

ClipExporter (DevCam/Core/ClipExporter.swift)
  - ObservableObject
  - owns: AVAssetExportSession, Timer

AppSettings (DevCam/Core/AppSettings.swift)
  - ObservableObject
  - uses: UserDefaults, AppStorage

SegmentInfo (DevCam/Models/SegmentInfo.swift)
  - data model for buffer segments

ClipInfo (DevCam/Models/ClipInfo.swift)
  - data model for saved clips

MenuBarView (DevCam/UI/MenuBarView.swift)
  - SwiftUI view
  - binds to: RecordingManager, ClipExporter, AppSettings
```

### Interaction Diagram (Runtime)

```
MenuBarView
  -> RecordingManager.startRecording()
  -> ClipExporter.exportClip(duration:)

RecordingManager
  -> BufferManager.addSegment(...)
  -> BufferManager.getCurrentBufferDuration()

ClipExporter
  -> BufferManager.getSegmentsForTimeRange(duration:)
  -> AppSettings.saveLocation
```

## Data Schemas

### SegmentInfo

Source: DevCam/Models/SegmentInfo.swift

```swift
struct SegmentInfo: Identifiable, Codable {
    let id: UUID
    let fileURL: URL
    let startTime: Date
    let duration: TimeInterval

    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }
}
```

Fields:
- id: Unique identifier for in-memory and UI references
- fileURL: Location of the segment file on disk
- startTime: When the segment began recording
- duration: Segment length in seconds (typically 60)
- endTime: Derived property used for range queries

### ClipInfo

Source: DevCam/Models/ClipInfo.swift

```swift
struct ClipInfo: Identifiable, Codable {
    let id: UUID
    let fileURL: URL
    let timestamp: Date
    let duration: TimeInterval
    let fileSize: Int64

    var fileSizeFormatted: String {
        let mb = Double(fileSize) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

Fields:
- id: Unique identifier for list rendering and persistence
- fileURL: Final clip file location
- timestamp: When the export completed
- duration: Total clip duration in seconds
- fileSize: File size in bytes
- fileSizeFormatted: Derived human-readable size for UI
- durationFormatted: Derived mm:ss display string for UI

## Startup and Shutdown Sequences

### Startup Sequence

```
App Launch
  -> AppDelegate initializes status item
  -> AppSettings loads persisted preferences
  -> PermissionManager checks screen recording access
  -> RecordingManager.startRecording()
     -> SCShareableContent queried
     -> SCStream configured and started
     -> startNewSegment() with AVAssetWriter
     -> segment timer begins
  -> MenuBarView updates to recording state
```

### Shutdown Sequence

```
User quits or stops recording
  -> RecordingManager.stopRecording()
     -> invalidate segment timer
     -> finishCurrentSegment()
     -> SCStream.stopCapture()
     -> release writer and stream resources
  -> BufferManager remains for cleanup as needed
  -> App exits
```

## Threading Model

Main actor:
- UI updates (SwiftUI)
- RecordingManager, BufferManager, ClipExporter, AppSettings
- ScreenCaptureKit sample handling (configured as `.main`)

Background queues:
- AVAssetExportSession runs off-main

Why this model:
- SwiftUI requires main-thread updates
- MainActor keeps shared state consistent
- Export is CPU and I/O heavy, so it stays off-main

## Error Handling Strategy

Permission errors:
```
if !CGPreflightScreenCaptureAccess() {
    throw PermissionError.denied
}
```

Storage errors:
```
if availableSpace < 2GB {
    stop recording
    notify user
}
```

Stream errors:
- Log error details
- Attempt restart with backoff for transient failures

Export errors:
- Fail gracefully with user-visible message
- Keep segments for retry

## Performance Optimizations

Recording:
- H.264 hardware encoding for low CPU usage
- Minimal frame processing
- 1-minute segments to balance disk I/O and manageability

Export:
- AVMutableComposition to avoid re-encoding per segment
- Background export session
- Timer-based progress polling to avoid tight loops

Memory:
- Segment data stored on disk
- In-memory metadata only

## Security and Privacy

Permissions:
- Screen recording permission required (enforced by macOS)
- App Sandbox enabled with screen capture and user-selected read/write entitlements

File access:
- Buffer directory managed by the app
- Clip export uses a user-selected folder chosen via NSOpenPanel
- Save location is persisted as a path (no security-scoped bookmark handling yet)

Network:
- No network features by design
- No telemetry or analytics

## Extensibility

Audio recording:
- System audio capture via ScreenCaptureKit is implemented
- Microphone capture and audio export stitching are not implemented

Multi-display:
- Display selection in Preferences is implemented
- All-displays capture and multi-stream compositing are not implemented

Clip trimming:
- Advanced clip window supports timeline trim and custom duration
- Preview and audio-inclusive trimming remain future work

## Conclusion

DevCam is structured around three core concerns:
1) Continuous recording
2) Safe and efficient buffering
3) Fast clip exports

The separation between RecordingManager, BufferManager, and ClipExporter keeps
performance-sensitive code isolated while allowing the UI and settings to
evolve independently.
