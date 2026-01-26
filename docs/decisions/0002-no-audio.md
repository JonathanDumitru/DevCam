# ADR 0002: No Audio Capture

Status: Accepted
Date: 2026-01-23

## Context
DevCam targets quick developer screen capture for debugging and demos.
Capturing audio adds privacy concerns, extra permissions, and more resource use.

## Decision
Capture screen video only. RecordingManager configures ScreenCaptureKit for video
frames, and ClipExporter composes only video tracks.

## Consequences
- Lower complexity, smaller files, and fewer privacy concerns.
- Users cannot capture microphone or system audio.

## Alternatives Considered
- Optional audio toggle for microphone or system audio.
- Separate audio-only recording.
