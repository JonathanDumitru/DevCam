# DevCam Testing Session - 2026-01-23

**Testing Start:** 2026-01-23
**Tester:** User + Claude Code
**Build:** Development build from source (pre-release)
**macOS Version:** Darwin 25.3.0
**Environment:** Console.app monitoring active

## Testing Objectives

1. **Functional Verification** - Confirm all implemented features work as documented
2. **System Integration** - Verify macOS system event handling (sleep/wake, permissions)
3. **Performance Validation** - Measure CPU, memory, and disk usage under normal operation
4. **Error Handling** - Test edge cases and failure scenarios
5. **Documentation Accuracy** - Validate that user-facing docs match actual behavior

## Test Methodology

### Testing Phases
1. **Launch & Initialization** - App startup, permission requests, initial state
2. **Core Recording** - Continuous recording, buffer management, segment rotation
3. **Clip Export** - Save operations (5/10/15 min), export progress, notifications
4. **User Interface** - Menubar interaction, preferences window, shortcuts
5. **System Events** - Sleep/wake, display changes, permission handling
6. **Edge Cases** - Low disk space, interrupted exports, rapid saves

### Documentation Approach
For each test:
- **Test ID:** Unique identifier (e.g., `LAUNCH-01`, `RECORD-01`)
- **Description:** What we're testing and why
- **Expected Behavior:** What should happen (from docs/code)
- **Actual Behavior:** What actually happened
- **Console Output:** Relevant logs from Console.app
- **Result:** ✅ PASS | ⚠️ PARTIAL | ❌ FAIL
- **Notes:** Additional observations, performance data, edge cases discovered

---

## Test Results

### Phase 1: Launch & Initialization

#### Test LAUNCH-01: Clean Application Launch
**Description:** Launch DevCam for the first time (or after clearing preferences)
**Expected Behavior:**
- Menubar icon appears (⏺)
- Permission prompt displays if Screen Recording not granted
- App initializes RecordingManager, BufferManager, ExportManager
- No crashes or errors

**Actual Behavior:**
```
✅ App launched successfully (PID 10824)
✅ Process running for 6+ minutes without crashes
✅ Screen recording IS active (ControlCenter shows [scr] indicator)
❌ Menubar icon NOT visible in SystemUIServer
❌ No preferences file created (com.devcam.DevCam)
❌ No buffer directory created (~/Library/Caches/com.devcam.DevCam)
```

**Console Output:**
```
2026-01-23 09:59:49.948695-0500  DevCam: (AppKit) No windows open yet
2026-01-23 10:00:03.183473-0500  ControlCenter: [scr] DevCam (Jonathan-Hines-Dumitru.DevCam)
2026-01-23 10:00:04.790623-0500  ControlCenter: [scr] DevCam - Sorted active attributions
[Multiple ControlCenter entries showing DevCam screen recording active]

Process Info:
dev   10824   0.0  0.6 121872 S   0:00.49 DevCam.app
ELAPSED: 06:42 (running normally, not crashed)
```

**Result:** ⚠️ PARTIAL

**Notes:**
- **CRITICAL FINDING:** Screen recording IS working (ControlCenter logs prove it)
- **BUG:** Menubar status item not appearing despite setupStatusItem() being called
- **BUG:** No buffer directory created - segments not being written?
- AppKit logged "No windows open yet" - expected for menubar-only app
- Process stable, no crashes, minimal CPU/memory usage (0.6% memory)
- Need to investigate: Why statusItem not showing, why buffer not created

---

#### Test LAUNCH-02: Permission Grant Flow
**Description:** Grant Screen Recording permission when prompted
**Expected Behavior:**
- macOS system dialog appears requesting Screen Recording permission
- After granting, app may require restart (macOS behavior)
- Recording starts automatically after permission granted

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Document: Exact permission dialog text, restart requirement

---

#### Test LAUNCH-03: Save Location Selection
**Description:** Choose where clips will be saved
**Expected Behavior:**
- Preferences window opens or save panel appears
- User selects directory (defaults to ~/Movies/DevCam)
- Selection persists across app restarts

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Verify: UserDefaults persistence, directory creation if needed

---

### Phase 2: Core Recording

#### Test RECORD-01: Recording Start on Launch
**Description:** Verify recording begins automatically after initialization
**Expected Behavior:**
- RecordingManager.startRecording() called automatically
- ScreenCaptureKit stream starts
- Buffer segments begin writing to temp directory
- Console shows recording started logs

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Check: Buffer directory created, first segment file appears
- Monitor: CPU usage should be ~5%, memory ~200MB

---

#### Test RECORD-02: Buffer Segment Creation
**Description:** Verify 60-second segments are created and rotated
**Expected Behavior:**
- New segment created every ~60 seconds
- Segment filenames: `segment_YYYYMMDD_HHMMSS.mov`
- Max 15 segments maintained (15 minutes)
- Oldest segments deleted automatically when limit reached

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Watch for: Segment rotation logs, file deletion timing
- Verify: Buffer never exceeds 15 segments

---

#### Test RECORD-03: Buffer Duration Tracking
**Description:** Verify published bufferDuration updates correctly
**Expected Behavior:**
- RecordingManager.bufferDuration increments from 0 to 900 seconds (15 min)
- Menubar shows accurate buffer duration
- After 15 min, duration stays at 900 (rolling buffer)

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Monitor: Duration updates in menubar, accuracy of calculation

---

### Phase 3: Clip Export

#### Test EXPORT-01: Save Last 5 Minutes (Keyboard Shortcut)
**Description:** Press ⌘⇧5 to save 5 minutes of footage
**Expected Behavior:**
- Export begins immediately
- Progress indicator appears in menubar
- Notification shows export start
- Export completes with success notification
- Clip file created in save directory with correct filename pattern

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Time export duration, verify clip length matches 5 minutes
- Check: File size reasonable (~600MB for 5 min @ 16 Mbps)

---

#### Test EXPORT-02: Save Last 10 Minutes (Menubar)
**Description:** Click menubar icon → "Save Last 10 Minutes"
**Expected Behavior:**
- Same as EXPORT-01 but for 10 minutes
- Export creates larger file (~1.2GB)

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Compare: Menubar vs keyboard shortcut behavior (should be identical)

---

#### Test EXPORT-03: Save Last 15 Minutes (Full Buffer)
**Description:** Save entire 15-minute buffer
**Expected Behavior:**
- All 15 segments concatenated into single clip
- Largest export (~1.8GB)
- Verify no frame drops or concatenation artifacts

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Watch for: AVAssetExportSession completion, no errors

---

#### Test EXPORT-04: Export While Recording
**Description:** Trigger export while recording continues
**Expected Behavior:**
- Export runs in background
- Recording continues uninterrupted
- New segments still created during export
- Export completes successfully without corruption

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Critical: Verify no race conditions, segment corruption, or frame drops

---

#### Test EXPORT-05: Multiple Rapid Exports
**Description:** Trigger 2-3 exports in quick succession
**Expected Behavior:**
- Exports queue correctly (not necessarily sequential)
- Each export completes successfully
- No crashes or resource exhaustion

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Test: Export manager's concurrent operation handling

---

### Phase 4: User Interface

#### Test UI-01: Menubar Menu Items
**Description:** Click menubar icon and verify all menu items
**Expected Behavior:**
- "Save Last 5 Minutes" enabled if bufferDuration >= 300s
- "Save Last 10 Minutes" enabled if bufferDuration >= 600s
- "Save Last 15 Minutes" enabled if bufferDuration >= 900s
- "Preferences..." always enabled
- "Quit DevCam" always enabled

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Verify: Menu item enabling logic matches code (MenuBarView.swift:134)

---

#### Test UI-02: Preferences Window Opening
**Description:** Open Preferences from menubar or ⌘,
**Expected Behavior:**
- Preferences window opens
- Shows tabs: General, Shortcuts, Recording, Recent Clips
- Window is not menubar-only (appears as normal window)

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Check: Window positioning, size, tab navigation

---

#### Test UI-03: Recent Clips Browser
**Description:** Navigate to Recent Clips tab in Preferences
**Expected Behavior:**
- Lists all saved clips with thumbnails
- Shows filename, date, size
- Click to reveal in Finder or preview
- Empty state if no clips saved yet

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Verify: Clip list updates after new exports

---

#### Test UI-04: Keyboard Shortcut Customization
**Description:** Change default keyboard shortcuts in Preferences
**Expected Behavior:**
- Shortcuts tab shows current bindings
- Click to record new shortcut
- Validates for conflicts
- New shortcuts work immediately

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Test: Conflict detection, persistence across restarts

---

### Phase 5: System Events

#### Test SYSTEM-01: Sleep/Wake Handling
**Description:** Put Mac to sleep, then wake
**Expected Behavior:**
- Recording pauses on sleep
- Buffer preserved during sleep
- Recording resumes automatically on wake
- No crashes or data loss

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Check: NSWorkspace notification handling (RecordingManager.swift)

---

#### Test SYSTEM-02: Display Resolution Change
**Description:** Change display resolution while recording
**Expected Behavior:**
- Recording adapts to new resolution
- No crashes or stream interruption
- New segments use updated resolution

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Verify: ScreenCaptureKit stream reconfiguration

---

#### Test SYSTEM-03: External Display Connection
**Description:** Connect/disconnect external display (if available)
**Expected Behavior:**
- App detects display change
- Recording continues on primary display (or user-selected)
- Preferences allow choosing which display to record

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Multi-monitor support: Verify display selection logic

---

#### Test SYSTEM-04: Permission Revocation
**Description:** Revoke Screen Recording permission in System Settings
**Expected Behavior:**
- App detects permission loss
- Recording stops gracefully
- User notified via alert or menubar indicator
- App prompts to re-grant permission

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Critical: Permission monitoring, graceful degradation

---

### Phase 6: Edge Cases

#### Test EDGE-01: Low Disk Space
**Description:** Fill disk to <2GB free space
**Expected Behavior:**
- StorageMonitor detects low space
- User warned via notification
- Recording may pause to prevent system instability
- App doesn't crash or corrupt data

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Check: StorageMonitor.swift disk checking logic

---

#### Test EDGE-02: Save Before Buffer Full
**Description:** Save 5 minutes when only 2 minutes recorded
**Expected Behavior:**
- Export only available buffer (2 minutes)
- User informed of shorter duration
- No errors or empty clips

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Verify: MenuBarView.swift menu item enabling logic (line 134)

---

#### Test EDGE-03: Quit During Export
**Description:** Quit app while export in progress
**Expected Behavior:**
- App warns user about in-progress export
- Option to cancel export or wait for completion
- If forced quit, partial clip may be incomplete
- No buffer corruption

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Check: applicationShouldTerminate handler

---

#### Test EDGE-04: Rapid App Restart
**Description:** Quit and immediately relaunch DevCam
**Expected Behavior:**
- Old buffer cleaned up properly
- New buffer starts fresh
- No orphaned segment files
- Preferences persist correctly

**Actual Behavior:**
```
[Waiting for user testing...]
```

**Console Output:**
```
[User will paste relevant Console.app logs here]
```

**Result:** ⏸️ PENDING

**Notes:**
- Verify: Buffer directory cleanup, state management

---

## Performance Monitoring

### Baseline Metrics (Idle State)
Record these after app stabilizes (~2 minutes after launch):

- **CPU Usage:** _____% (Activity Monitor)
- **Memory Usage:** _____MB (Activity Monitor)
- **Disk Write Rate:** _____MB/s (Activity Monitor, Disk tab)
- **Buffer Directory Size:** _____MB (Finder, buffer location)
- **Thread Count:** _____ threads (Activity Monitor)

### Under Load Metrics (During Export)
Record these while exporting 15-minute clip:

- **CPU Usage:** _____% (Activity Monitor)
- **Memory Usage:** _____MB (Activity Monitor)
- **Export Duration:** _____ seconds (for 15-min clip)
- **Peak Disk I/O:** _____MB/s (Activity Monitor)

### Expected Performance Targets
(From README.md and Architecture docs)

- **CPU (Recording):** ~5% on 2020+ Mac
- **CPU (Exporting):** ~10-15%
- **Memory:** ~200MB typical
- **Disk I/O:** ~120 MB/min (2 MB/s) during recording
- **Buffer Size:** ~1.8GB for full 15-minute buffer

---

## Issues Discovered

### Issue LAUNCH-01: Menubar Icon Not Showing
**Severity:** 🔴 Critical
**Test ID:** LAUNCH-01
**Description:** DevCam launches successfully but menubar status item does not appear in SystemUIServer. App is unusable without menubar access.

**Steps to Reproduce:**
1. Build DevCam in Debug configuration
2. Launch DevCam.app
3. Check menubar for DevCam icon (⏺)
4. Icon does not appear

**Evidence:**
- Process running normally (PID 10824, 0.0% CPU, 0.6% MEM)
- `setupStatusItem()` called in code (line 85, DevCamApp.swift)
- `osascript` query confirms icon not in SystemUIServer menubar items
- ControlCenter shows app is using Screen Recording permission

**Console Logs:**
```
2026-01-23 09:59:49.948695-0500  DevCam: (AppKit) No windows open yet
[No errors or warnings logged]
```

**Proposed Fix:** Investigate NSStatusBar.system.statusItem creation. Possible causes:
- Status item created but button image not set correctly
- NSApp.setActivationPolicy(.accessory) interfering with status item
- Timing issue - status item created before app fully initialized

---

### Issue LAUNCH-02: No Video Segments Written
**Severity:** 🔴 Critical
**Test ID:** LAUNCH-01, RECORD-01
**Description:** Buffer directory created but remains empty. No video segments are written despite ControlCenter showing active screen recording.

**Steps to Reproduce:**
1. Launch DevCam
2. Wait 2+ minutes (should have 2+ segment files)
3. Check buffer directory: `/Users/dev/Library/Application Support/DevCam/buffer/`
4. Directory is empty

**Evidence:**
- Buffer directory exists and has correct permissions (drwxr-xr-x)
- Created at 07:53 AM but still empty at 10:01 AM
- ControlCenter logs show `[scr] DevCam` multiple times (screen recording active)
- No .mov files in lsof output for DevCam process
- No segment_YYYYMMDD_HHMMSS.mov files present

**Console Logs:**
```
2026-01-23 10:00:03.183473-0500  ControlCenter: [scr] DevCam (Jonathan-Hines-Dumitru.DevCam)
[Repeated every 10-30 seconds, showing DevCam as active screen recorder]
```

**Proposed Fix:** Investigate RecordingManager.startRecording():
- Check if ScreenCaptureKit stream actually started
- Verify AVAssetWriter pipeline initialization
- Check if AVAssetWriter.startWriting() was called
- Look for suppressed errors in RecordingManager

**Critical:** ControlCenter showing `[scr]` indicator does NOT prove video is being captured—only that permission is being used. Stream may have failed silently after permission grant.

---

### Issue LAUNCH-03: No OSLog Output
**Severity:** 🟡 Medium
**Test ID:** LAUNCH-01
**Description:** DevCamLogger configured but no logs appear in system log despite app running for 7+ minutes.

**Steps to Reproduce:**
1. Launch DevCam
2. Query unified log: `log show --predicate 'subsystem == "Jonathan-Hines-Dumitru.DevCam"'`
3. No results returned

**Evidence:**
- DevCamLogger.swift properly configured (subsystem: "Jonathan-Hines-Dumitru.DevCam")
- Code calls DevCamLogger.app.info("Application launching") on line 51
- Code calls DevCamLogger.app.info("Managers initialized") on line 187
- log show returns no entries for this subsystem

**Proposed Fix:**
- Verify OSLog is enabled for Debug builds (may require entitlement)
- Add NSLog fallback for debugging
- Check if logs are being filtered by system privacy settings

---

### Issue UI-01: Preferences Window Causes Application Freeze
**Severity:** 🔴 Critical
**Test ID:** UI-02 (Preferences Window Opening)
**Description:** Opening the Preferences window causes the entire application to freeze. App becomes unresponsive and must be force-quit.

**Steps to Reproduce:**
1. Launch DevCam from Xcode (⌘R)
2. Click menubar icon or press ⌘,
3. Select "Preferences..." from menu
4. Application freezes immediately
5. App is completely unresponsive, requires force quit

**Evidence:**
- User reports: "preferences causes the application to freeze now"
- Occurred during Xcode testing session
- Likely introduced by recent changes (debug logging or previous modifications)
- showPreferences() called in DevCamApp.swift line 229

**Root Cause (IDENTIFIED via crash report):**

**Crash Type:** `EXC_BAD_ACCESS (SIGSEGV)` - Null pointer dereference
**Location:** `objc_msgSend` trying to send message to NULL object
**Thread:** Main thread (com.apple.main-thread)

**Stack Trace Analysis:**
```
objc_msgSend+56 → NULL dereference
swift_getObjectType → Trying to get type of nil object
swift_task_isMainExecutorImpl → MainActor isolation check
MainActor.assumeIsolated<A>(_:file:line:) → SwiftUI trying to verify main thread
_ButtonGesture.internalBody.getter → User clicked "Preferences..." button
```

**The Bug:**
When user clicks "Preferences..." button in menubar:
1. Button action closure executes: `onPreferences()` (line 142, MenuBarView.swift)
2. This calls AppDelegate's closure (line 139-141, DevCamApp.swift):
   ```swift
   onPreferences: { [weak self] in
       self?.menuBarPopover?.close()
       self?.showPreferences()  // ← This line
   }
   ```
3. `showPreferences()` creates PreferencesWindow with:
   ```swift
   let prefsView = PreferencesWindow(
       settings: settings,           // ← One of these is NIL
       permissionManager: permissionManager,
       clipExporter: clipExporter
   )
   ```
4. One of these managers is `nil` (likely uninitialized)
5. SwiftUI tries to access the nil object → CRASH

**Why are managers nil?**
Checking setupManagers() execution order - if managers aren't fully initialized before UI setup, they'll be nil when PreferencesWindow tries to access them as `@ObservedObject`.

**Proposed Fix:**
1. Add nil checks before creating PreferencesWindow
2. Ensure setupManagers() completes before setupStatusItem()
3. Add guard statements in showPreferences():
   ```swift
   guard let settings = settings,
         let permissionManager = permissionManager,
         let clipExporter = clipExporter else {
       print("❌ ERROR: Cannot show preferences - managers not initialized")
       return
   }
   ```

**Priority:** 🔴 CRITICAL - Crash on user interaction, blocks all preference access

**Fix Applied:**
Added nil-safety guard in `showPreferences()` (DevCamApp.swift:237-246):
```swift
guard let settings = settings,
      let clipExporter = clipExporter else {
    print("❌ ERROR: Cannot show preferences - managers not initialized!")
    print("   settings: \(settings != nil ? "OK" : "NIL")")
    print("   clipExporter: \(clipExporter != nil ? "OK" : "NIL")")
    return
}
```

**Fix Status:** ✅ IMPLEMENTED - Build successful, awaiting user testing

**How to Verify Fix:**
1. Launch DevCam from Xcode (⌘R)
2. Watch Xcode console for startup debug messages
3. Click menubar icon → "Preferences..."
4. Check console for manager initialization status
5. Verify Preferences window opens without crash

**Expected Behavior After Fix:**
- If managers are initialized: Preferences window opens successfully
- If managers are nil: Guard catches it, logs error, returns gracefully (no crash)

---

### Issue Template
Use this format for any issues found during testing:

```
#### Issue [CATEGORY-##]: Brief Title

**Severity:** 🔴 Critical | 🟡 Medium | 🟢 Low
**Test ID:** [Which test discovered this]
**Description:** Clear explanation of the issue
**Steps to Reproduce:**
1. Step one
2. Step two
3. Expected vs actual behavior

**Console Logs:**
```
[Relevant error logs]
```

**Screenshots/Videos:** [If applicable]
**Workaround:** [If known]
**Proposed Fix:** [If obvious]
```

---

## Test Session Summary

**Total Tests Planned:** 26
**Tests Completed:** 0
**Tests Passed:** 0
**Tests Failed:** 0
**Tests Partial:** 0
**Tests Skipped:** 0

**Critical Issues Found:** 0
**Medium Issues Found:** 0
**Low Issues Found:** 0

**Overall Assessment:** ⏸️ Testing in progress

**Next Steps:**
1. User begins testing with Phase 1 (Launch & Initialization)
2. Update this document with results after each test
3. Paste Console.app logs for each test
4. Report any unexpected behavior immediately
5. After all tests complete, generate summary report for Codex

---

## Notes for Codex

**Testing Context:**
- This is the first comprehensive test session after implementing all core features
- README.md was just updated to reflect production-ready state
- All documentation claims this test session will validate
- Application built from source (no release builds yet)

**Key Areas of Focus:**
1. Verify all features documented in README.md actually work
2. Validate technical specifications (60fps, H.264, 15-min buffer, etc.)
3. Test system integration (macOS 12.3+, ScreenCaptureKit)
4. Identify any gaps between documentation and actual behavior
5. Document performance characteristics for optimization

**For Future Maintenance:**
- Update this template for subsequent test sessions (version it: TEST_SESSION_YYYY-MM-DD.md)
- Cross-reference any issues found with GitHub issues (when repo is public)
- Use test results to inform ROADMAP.md updates
- Flag any breaking changes that require documentation updates
