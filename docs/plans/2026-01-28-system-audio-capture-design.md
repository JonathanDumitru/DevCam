# System Audio Capture - Design Document

**Date:** 2026-01-28
**Status:** Approved for implementation

## Overview

Complete the partially-implemented system audio capture feature in DevCam. The goal is to allow users to capture system sounds (app audio, notifications, video playback) alongside screen recordings.

## Current State

### What's Already Implemented
- `AudioCaptureMode` enum with four options (none, system, microphone, both)
- UI picker in Preferences → Recording tab
- ScreenCaptureKit configuration (`config.capturesAudio = true`)
- Audio stream output registration on SCStream
- AVAssetWriterInput for AAC audio encoding (48kHz stereo)
- `processAudioSampleBuffer()` callback that writes audio frames

### What's Broken
1. **Audio input not finalized** - `currentAudioInput.markAsFinished()` is never called during segment rotation, causing corrupt audio at segment boundaries
2. **ClipExporter ignores audio** - Only video tracks are stitched; audio tracks are silently dropped during export

## Design Decisions

### Scope: System Audio Only
- Microphone capture is out of scope for this change
- System audio via ScreenCaptureKit is simpler (no additional permissions beyond screen recording)
- Microphone can be added later as a separate enhancement

### Default Behavior
- Keep `audioCaptureMode` defaulting to `.none`
- No behavior change for existing users
- User must explicitly opt-in via Preferences

### UI Changes
- None required - existing picker and info labels are sufficient

## Implementation

### RecordingManager Changes

In `finalizeCurrentSegment()`:
1. Call `currentAudioInput?.markAsFinished()` before video input
2. Reset `currentAudioInput = nil` after writer finishes

### ClipExporter Changes

In `createComposition(from:)`:
1. Check if segments contain audio tracks
2. Create audio composition track if audio exists
3. Insert audio time ranges alongside video for each segment
4. Handle mixed segments gracefully (skip audio for segments without it)

## Testing Strategy

### Manual Verification
1. Enable system audio in preferences
2. Play audio content while recording
3. Wait for multiple segment rotations
4. Export clip and verify audio in QuickTime

### Automated Tests
- Unit test for composition with audio tracks
- Unit test for mixed audio/no-audio segment handling

## Risk Assessment

**Low risk** - Changes are isolated to two methods in two files. No architectural changes required.
