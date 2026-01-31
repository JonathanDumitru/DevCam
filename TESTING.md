# DevCam Manual Testing Guide

## Pre-Test Setup
- [ ] Grant Screen Recording permission when prompted
- [ ] Note the save location (default: ~/Movies/DevCam/)

## Test 1: Launch and Menubar
**Goal**: Verify app launches and shows menubar icon

Steps:
1. Launch DevCam.app from Xcode or Finder
2. Check menubar for DevCam icon (record circle)
3. Click the menubar icon
4. Verify popover appears with menu

Expected:
- ✅ Menubar icon visible
- ✅ Status shows "Recording" or "Paused"
- ✅ Buffer duration displays (0:00 / 15:00)
- ✅ Save Clip slider and Save/Advanced buttons visible
- ✅ Preferences and Quit options

---

## Test 2: Recording Status
**Goal**: Verify recording starts automatically

Steps:
1. Observe the status in menubar popover
2. Wait 10 seconds
3. Check if buffer duration increases

Expected:
- ✅ Status indicator is red (recording)
- ✅ Status text shows "Recording"
- ✅ Buffer duration increments
- ✅ No error messages

---

## Test 3: Save Clips (Menu)
**Goal**: Test clip export via the menubar slider and Advanced flow

Steps:
1. Wait for at least 1 minute of buffer
2. Set the Save Clip slider to 1-5 minutes and click "Save Clip"
3. Wait for export to complete
4. Check save location for exported file
5. Click "Advanced...", set a custom start/end range, and export

Expected:
- ✅ Export progress bar appears
- ✅ Progress reaches 100%
- ✅ Notification appears (if enabled)
- ✅ File exists at ~/Movies/DevCam/DevCam_YYYY-MM-DD_HH-MM-SS.mp4
- ✅ File can be opened in QuickTime Player
- ✅ Advanced export completes successfully

---

## Test 4: Keyboard Shortcuts
**Goal**: Test app-local keyboard shortcuts

Steps:
1. Click the menubar icon to focus DevCam
2. Press Cmd+Option+5 (with DevCam active)
3. Wait for export
4. Try Cmd+Option+6 and Cmd+Option+7
5. Check save location for files

Expected:
- ✅ Cmd+Option+5 saves 5-minute clip
- ✅ Cmd+Option+6 saves 10-minute clip
- ✅ Cmd+Option+7 saves 15-minute clip
- ✅ All files created successfully
- ✅ Keyboard events consumed (don't trigger other apps)

---

## Test 5: Preferences Window
**Goal**: Test preferences access and display

Steps:
1. Click menubar icon
2. Click "Preferences..."
3. Verify window opens

Expected:
- ✅ Preferences window appears
- ✅ Three tabs visible: General, Clips, Privacy
- ✅ Window is 500x400
- ✅ All tabs accessible

---

## Test 6: General Tab
**Goal**: Test general settings

Steps:
1. Open Preferences → General
2. Click "Choose..." for save location
3. Select a different folder
4. Toggle "Launch at Login"
5. Toggle "Show Notifications"
6. Change Recording Quality
7. Quit and relaunch DevCam

Expected:
- ✅ Save location displays current path
- ✅ Folder picker opens
- ✅ New location is saved
- ✅ Toggles work and persist
- ✅ About section shows version
- ✅ Recording quality persists after relaunch

---

## Test 7: Clips Tab
**Goal**: Test recent clips browser

Steps:
1. Save 2-3 clips (if not already done)
2. Open Preferences → Clips
3. Click play icon on a clip
4. Click folder icon
5. Click trash icon

Expected:
- ✅ Clips list shows recent exports
- ✅ Metadata correct (duration, size, timestamp)
- ✅ Play opens clip in default player
- ✅ Folder opens Finder at clip location
- ✅ Trash deletes clip and removes from list
- ✅ "Clear All" removes all clips from list
- ✅ Empty state shows when no clips

---

## Test 8: Privacy Tab
**Goal**: Verify privacy information

Steps:
1. Open Preferences → Privacy
2. Check permission status
3. Read privacy policy
4. Click "Open System Settings" (if needed)

Expected:
- ✅ Permission status correct (granted/required)
- ✅ Status indicator shows green checkmark (if granted)
- ✅ Privacy policy clearly explains:
  - What is stored
  - What is NOT stored
  - Storage locations
- ✅ System Settings link works

---

## Test 9: Buffer Management
**Goal**: Verify buffer rotation and cleanup

Steps:
1. Let app record for 2 minutes
2. Check buffer directory: ~/Library/Application Support/DevCam/buffer/
3. List files: `ls -lh ~/Library/Application\ Support/DevCam/buffer/`
4. Continue recording for 16+ minutes
5. Check if old segments are deleted

Expected:
- ✅ Segment files created (segment_*.mp4)
- ✅ Files approximately 1 minute each
- ✅ After 16 minutes, only 15 segments remain
- ✅ Oldest segment deleted when new one created

---

## Test 10: System Sleep/Wake
**Goal**: Test pause/resume on sleep

Steps:
1. Start recording
2. Put Mac to sleep (⌘⌥⏏ or close lid)
3. Wait 10 seconds
4. Wake Mac
5. Check recording status

Expected:
- ✅ Recording pauses on sleep
- ✅ Recording resumes on wake
- ✅ No crashes or errors
- ✅ Buffer continues from where it left off

---

## Test 11: Concurrent Export Prevention
**Goal**: Ensure only one export at a time

Steps:
1. Start a clip export (15 minutes)
2. While exporting, try to start another export
3. Check if second export is blocked

Expected:
- ✅ First export proceeds normally
- ✅ Second export is blocked (button disabled)
- ✅ After first completes, can start new export

---

## Test 12: Error Handling
**Goal**: Test graceful error handling

Steps:
1. Try to save when buffer is empty (fresh launch)
2. Try to save 10 minutes when only 2 minutes recorded
3. Change save location to read-only folder
4. Try to export

Expected:
- ✅ Save buttons disabled when insufficient buffer
- ✅ Exports available time if less than requested
- ✅ Error shown if save location invalid
- ✅ No crashes on error conditions

---

## Test 13: Resource Usage
**Goal**: Verify performance is acceptable

Steps:
1. Open Activity Monitor
2. Let DevCam record for 5 minutes
3. Monitor CPU and Memory usage

Expected:
- ✅ CPU < 10% during idle recording
- ✅ Memory < 300MB
- ✅ No memory leaks (stable over time)
- ✅ Disk writes steady (buffer segments)

---

## Test 14: Quit Behavior
**Goal**: Test clean shutdown

Steps:
1. While recording, click "Quit DevCam"
2. Relaunch app
3. Check buffer directory

Expected:
- ✅ App quits cleanly
- ✅ No crash dialogs
- ✅ Buffer segments preserved
- ✅ On relaunch, starts fresh recording

---

## Issues Found

Document any issues here:

| Issue | Severity | Description | Steps to Reproduce |
|-------|----------|-------------|-------------------|
|       |          |             |                   |

---

## Test Results Summary

Date: ___________
Tester: ___________

Tests Passed: __ / 14
Tests Failed: __ / 14

Overall Status: ☐ Pass  ☐ Fail  ☐ Needs Fixes

Notes:
