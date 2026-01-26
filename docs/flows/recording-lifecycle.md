# Flow: Recording Lifecycle

Goal: Start recording automatically at launch and maintain a rolling buffer.

Entry points
- DevCam/DevCam/DevCamApp.swift: AppDelegate.applicationDidFinishLaunching -> setupManagers -> startRecording.

Steps
1. setupManagers creates AppSettings, BufferManager, RecordingManager, and ClipExporter.
2. startRecording launches a Task and calls RecordingManager.startRecording.
3. RecordingManager checks PermissionManager.hasScreenRecordingPermission.
4. RecordingManager.setupAndStartStream selects the primary display and configures SCStream.
5. VideoStreamOutput receives frames and writes them via AVAssetWriter.
6. A 60-second segment timer finalizes each segment and starts a new one.
7. BufferManager.addSegment stores SegmentInfo and evicts the oldest segment when over 15 segments.
8. RecordingManager publishes bufferDuration for UI display.

Notes
- RecordingManager registers sleep and wake observers and pauses or resumes the stream.
- In test mode, RecordingManager uses a test recording path instead of ScreenCaptureKit.
