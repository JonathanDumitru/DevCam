# ADR 0002: No Audio Capture

Status: Superseded (2026-01-31)
Date: 2026-01-23

## Context
DevCam targets quick developer screen capture for debugging and demos.
Capturing audio adds privacy concerns, extra permissions, and more resource use.

## Decision
Capture screen video only. RecordingManager configures ScreenCaptureKit for video
frames, and ClipExporter composes only video tracks.

## Update (2026-01-31)
System audio capture is now wired in RecordingManager and exposed in the Recording tab.
Microphone capture and audio export stitching are not implemented yet, so exported
clips remain video-only.

## Consequences
- Lower complexity, smaller files, and fewer privacy concerns.
- Users cannot capture microphone audio yet, and exported clips are video-only.

## Alternatives Considered
- Optional audio toggle for microphone or system audio.
- Separate audio-only recording.
