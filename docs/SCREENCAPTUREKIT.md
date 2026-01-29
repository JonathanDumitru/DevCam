# ScreenCaptureKit Integration Guide

This document explains how DevCam integrates with ScreenCaptureKit for high
performance screen recording. ScreenCaptureKit was introduced in macOS 12.3,
while DevCam targets macOS 13.0+ due to ServiceManagement login item support.

Status: RecordingManager, VideoStreamOutput, and ClipExporter are implemented. Menubar and Preferences UI are wired; some settings remain stubs.

## Why ScreenCaptureKit

ScreenCaptureKit is Apple's modern screen recording API. Compared to older
APIs, it provides better performance, improved privacy integration, and native
multi-display support.

| Feature | ScreenCaptureKit | Legacy APIs |
| --- | --- | --- |
| Performance | Hardware accelerated | Often software |
| CPU Usage | Low | Higher |
| Max FPS | 60+ | 30 (typical) |
| Privacy | Integrated with macOS | Manual handling |
| Multi-display | Native support | Complex setup |

## Permission Flow

DevCam centralizes permission handling in `DevCam/DevCam/Utilities/PermissionManager.swift`.
Use it instead of calling the APIs directly from the UI.

### Check Permission
```
import ScreenCaptureKit

let permissionManager = PermissionManager()
let status = permissionManager.screenRecordingPermissionStatus()
```

### Request Permission
```
permissionManager.requestScreenRecordingPermission()
```

Notes:
- The system prompt is shown by macOS, not the app.
- A relaunch may be required after granting permission.
- Use `permissionManager.openSystemSettings()` to deep-link to the privacy pane.

## Fetch Shareable Content

```
let content = try await SCShareableContent.excludingDesktopWindows(
    false,
    onScreenWindowsOnly: true
)

let displays = content.displays
let windows = content.windows
let apps = content.applications
```

DevCam selects the display with the largest resolution by default.

## Configure the Stream

```
let streamConfig = SCStreamConfiguration()
streamConfig.width = display.width
streamConfig.height = display.height
streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
streamConfig.showsCursor = true
streamConfig.colorSpaceName = CGColorSpace.sRGB
streamConfig.queueDepth = 5
```

Additional options:
- colorSpaceName: use sRGB for compatibility
- capturesAudio: only if audio capture is enabled

## Content Filters

### Full Display
```
let filter = SCContentFilter(display: display, excludingWindows: [])
```

### Exclude Specific Windows
```
let filter = SCContentFilter(
    display: display,
    excludingWindows: [myWindow]
)
```

### Capture a Specific Window
```
let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
```

DevCam uses the full display filter by default.

## Creating and Starting the Stream

```
let stream = SCStream(
    filter: filter,
    configuration: streamConfig,
    delegate: self
)

try stream.addStreamOutput(
    self,
    type: .screen,
    sampleHandlerQueue: .main
)

try await stream.startCapture()
```

## Handling Frame Output

Implementation note: the capture pipeline lives under `DevCam/DevCam/Core/`.
`RecordingManager.swift` conforms to SCStreamDelegate, and `VideoStreamOutput`
conforms to SCStreamOutput and forwards frames to RecordingManager on the main actor.

### SCStreamOutput
```
class VideoStreamOutput: NSObject, SCStreamOutput {
    private weak var recordingManager: RecordingManager?

    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        Task { @MainActor in
            await recordingManager?.processSampleBuffer(sampleBuffer)
        }
    }
}
```

### SCStreamDelegate
```
extension RecordingManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Log and attempt restart if appropriate
    }
}
```

## Video Encoding with AVAssetWriter

### Writer Setup
```
let writer = try AVAssetWriter(outputURL: segmentURL, fileType: .mp4)

let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: display.width,
    AVVideoHeightKey: display.height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 5_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoExpectedSourceFrameRateKey: 60
    ]
]

let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
videoInput.expectsMediaDataInRealTime = true
```

### Append Frames
```
guard videoInput.isReadyForMoreMediaData else { return }
videoInput.append(sampleBuffer)
```

## Segment Rotation

DevCam writes in 1-minute segments:
1. Start a new writer and session
2. Append frames for 60 seconds
3. Finalize writer and close file
4. Register segment in BufferManager

This enables a rolling buffer with predictable storage usage. The BufferManager
API is referenced in `DevCam/DevCamTests/BufferManagerTests.swift` and should be
implemented in `DevCam/DevCam/Core/BufferManager.swift`.

## Stream Restart Strategy

When the stream stops unexpectedly:
- Log the error
- Attempt restart with backoff
- Notify the UI if restart fails

Example:
```
func stream(_ stream: SCStream, didStopWithError error: Error) {
    Task {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await restartStream()
    }
}
```

## Performance Tuning

### Pixel Format
- Use kCVPixelFormatType_32BGRA for best compatibility

### Frame Rate Control
```
streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
```

### Queue Depth
```
streamConfig.queueDepth = 3
```

Increase if buffers are dropped, decrease for lower latency.

## Common Issues

### Black Screen
Cause: missing permission or revoked access.
Fix: request permission and relaunch.

### Dropped Frames
Cause: writer not ready or system under load.
Fix: check isReadyForMoreMediaData before appending.

### Stream Stops Unexpectedly
Cause: display changes or system sleep.
Fix: handle delegate error and restart.

### High CPU Usage
Cause: software encoding or inefficient settings.
Fix: ensure H.264 hardware encoding and BGRA pixel format.

### Crash on Recording Startup
Cause: AVAssetWriterInput rejects output settings keys and throws an exception.
Fix: capture the crash log and attach it to the incident report (see `docs/CURRENT_STATE.md`).

## Testing

### Manual Testing
- Permission flow on first launch
- Export after 5, 10, 15 minutes
- Display changes with external monitor
- Sleep and wake transitions

### Unit Testing
```
@MainActor
func testStreamConfiguration() {
    let config = SCStreamConfiguration()
    config.width = 1920
    config.height = 1080
    config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

    XCTAssertEqual(config.width, 1920)
    XCTAssertEqual(config.height, 1080)
}
```

## References
- Apple Developer: ScreenCaptureKit
  - https://developer.apple.com/documentation/screencapturekit
- WWDC 2021: Meet ScreenCaptureKit
  - https://developer.apple.com/videos/play/wwdc2021/10156/
- AVFoundation Programming Guide
  - https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/
- VideoToolbox Framework
  - https://developer.apple.com/documentation/videotoolbox
