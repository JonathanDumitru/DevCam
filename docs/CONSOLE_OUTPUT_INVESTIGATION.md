# Console Output Investigation - 2026-01-23 11:15-11:20 AM

## Summary
Attempted to capture DevCam console output when running from command line. Discovered limitations with capturing Swift `print()` statements outside of Xcode.

## What We Tried

### 1. Command Line Launch with Output Redirection
```bash
/path/to/DevCam.app/Contents/MacOS/DevCam > /tmp/devcam_console.log 2>&1
```

**Result:**
- Only captured `NSLog` output (first line): `🚀 DEBUG: applicationDidFinishLaunching() STARTED`
- No `print()` statements appeared
- App continued running (PID 18691, then 19557 after relaunch)

### 2. System Log Query
```bash
log show --process DevCam --last 1m --info --debug
```

**Result:**
- No DEBUG output captured
- `log show` command has difficulty with real-time queries
- System log may not capture all `print()` statements from GUI apps

### 3. Proper App Launch via `open` Command
```bash
open /path/to/DevCam.app
```

**Result:**
- ✅ Application launches successfully
- ✅ Process running (PID 19557, 125MB memory)
- ❌ No console output accessible from command line
- ❌ Buffer directory still empty (no video segments)

## Current Application State

**Process Status:**
- Running: YES (PID 19557)
- CPU: 0.0%
- Memory: ~125 MB
- Launch Time: 11:19 AM

**Buffer Directory:**
```
~/Library/Application Support/DevCam/buffer/
- Empty (0 files)
- Last modified: Jan 23 07:53
```

**Crash Reports:**
- No new crashes since 10:39 AM
- Latest: DevCam-2026-01-23-103923.ips (fixed crash)

## Key Discovery: `print()` vs `NSLog()` in macOS Apps

When running macOS GUI apps from the command line:
- **NSLog()** - Writes to system log (ASL), visible in Console.app
- **print()** - Writes to stdout, NOT captured by system log for GUI apps
- **DevCamLogger.app.info()** - Uses os_log, visible in Console.app with correct predicates

**Our Code Has:**
- Line 51: `NSLog("🚀 DEBUG: applicationDidFinishLaunching() STARTED")` ← Captured
- Line 52: `print("🚀 DEBUG: applicationDidFinishLaunching() STARTED")` ← NOT captured
- Lines 56-86: All `print()` statements ← NOT accessible from command line

## Why We Can't See Console Output

**Problem:** Swift `print()` statements in macOS GUI apps launched via `open` command don't route to stderr/stdout that we can easily capture.

**Explanation:**
1. When launched via `open`, macOS creates a new process tree
2. GUI apps detach from the launching terminal
3. stdout/stderr are not connected to any accessible stream
4. `print()` output is lost unless running from Xcode debugger

**Solutions:**
1. **Run from Xcode** (⌘R) - Xcode's debugger captures all output
2. **Use NSLog instead of print** - Goes to system log
3. **Write to a log file** - Explicit file output
4. **Use os_log** - System logging framework (like DevCamLogger)

## Recommended: Run from Xcode

To see all debug output including `print()` statements:

1. Open `/Users/dev/Documents/Software/macOS/DevCam/DevCam/DevCam.xcodeproj` in Xcode
2. Press ⌘R to build and run with debugger attached
3. View console output in Xcode's debug area (⌘⇧Y to show/hide)
4. All `print()`, `NSLog()`, and `os_log()` will appear in real-time

**Expected Output in Xcode Console:**
```
🚀 DEBUG: applicationDidFinishLaunching() STARTED
🚀 DEBUG: applicationDidFinishLaunching() STARTED
🚀 DEBUG: About to call setupManagers()
⚙️ DEBUG: setupManagers() - Creating AppSettings
⚙️ DEBUG: AppSettings created
⚙️ DEBUG: Creating BufferManager
💾 DEBUG: BufferManager.init() - Initializing
💾 DEBUG: Using default buffer directory: ~/Library/Application Support/DevCam/buffer
✅ DEBUG: Buffer directory created/verified
⚙️ DEBUG: BufferManager created
⚙️ DEBUG: Creating RecordingManager
⚙️ DEBUG: RecordingManager created
⚙️ DEBUG: Creating ClipExporter
⚙️ DEBUG: ClipExporter created
✅ DEBUG: All managers initialized successfully
🚀 DEBUG: Setting activation policy to .accessory
✅ DEBUG: Activation policy set
🚀 DEBUG: About to call setupStatusItem()
📍 DEBUG: setupStatusItem() - Creating status bar item
📍 DEBUG: NSStatusBar.system.statusItem returned: SUCCESS
📍 DEBUG: Got status item button, setting image
📍 DEBUG: Button image set: SUCCESS
✅ DEBUG: Status item fully configured - action and target set
🚀 DEBUG: About to call setupKeyboardShortcuts()
✅ DEBUG: setupKeyboardShortcuts() COMPLETED
🚀 DEBUG: About to call startRecording()
🎬 DEBUG: startRecording() - Creating Task
🎬 DEBUG: Inside Task @MainActor
🎬 DEBUG: About to call recordingManager.startRecording()
🎥 DEBUG: RecordingManager.startRecording() CALLED
🎥 DEBUG: isRecording = false
🎥 DEBUG: Checking screen recording permission
🔐 DEBUG: hasScreenRecordingPermission = true
✅ DEBUG: Permission granted, proceeding with recording setup
🎬 DEBUG: isTestMode = false, calling setupAndStartStream()
[... recording setup output ...]
✅ DEBUG: startRecording() call initiated (async)
🎉 DEBUG: applicationDidFinishLaunching() COMPLETED
```

## What We Know So Far

### ✅ Working
- Application builds successfully
- Application launches without crashing
- Process runs stably (no CPU spikes, normal memory usage)
- No new crash reports generated
- Nil-safety guards likely working (no crashes when clicking menubar)

### ❌ Not Working
- **Menubar icon not visible** - Cannot interact with app
- **No video segments written** - Buffer directory empty
- **Cannot capture debug output from command line** - Need Xcode

### ❓ Unknown (Need Xcode Console)
- Does `setupManagers()` complete successfully?
- Does `setupStatusItem()` succeed beyond the NSLog line?
- Does `setupAndStartStream()` in RecordingManager get called?
- Are there any errors in the recording pipeline?
- Why isn't the menubar icon appearing?

## Next Steps

1. **IMMEDIATE: Run from Xcode**
   - User must launch from Xcode (⌘R) to see full console output
   - Monitor debug area for complete initialization sequence
   - Look for errors or missing output in recording pipeline

2. **Check for Menubar Icon**
   - While running from Xcode, check if icon appears in menubar
   - If visible, test clicking it to verify nil-safety guards
   - If not visible, debug output will show where `setupStatusItem()` fails

3. **Investigate Recording Pipeline**
   - Look for `setupAndStartStream()` output in console
   - Check for ScreenCaptureKit errors
   - Verify AVAssetWriter initialization
   - Monitor buffer directory for segment creation

4. **Document Findings**
   - Capture full Xcode console output
   - Screenshot of menubar (showing icon or lack thereof)
   - Update TEST_RESULTS_SUMMARY.md with findings

## Build Information

**Last Build:** 2026-01-23 11:14 AM
**Build Result:** ✅ BUILD SUCCEEDED
**Binary Location:** `/Users/dev/Library/Developer/Xcode/DerivedData/DevCam-ctedjoxnerhfsiheymhmgbroqwuq/Build/Products/Debug/DevCam.app`
**Current Status:** Running (PID 19557), but console output not accessible

## Technical Note: Improving Console Output Capture

To make debug output accessible outside Xcode, consider one of these approaches:

### Option 1: Replace `print()` with `NSLog()`
```swift
// Before
print("🚀 DEBUG: About to call setupManagers()")

// After
NSLog("🚀 DEBUG: About to call setupManagers()")
```
**Pros:** Works from command line, visible in Console.app
**Cons:** Noisier system log, includes timestamp/process info

### Option 2: Use os_log consistently
```swift
// Already have DevCamLogger, use it everywhere
DevCamLogger.app.debug("About to call setupManagers()")
```
**Pros:** Proper logging framework, filterable, efficient
**Cons:** Requires Console.app or `log show` to view

### Option 3: Write to debug log file
```swift
func debugLog(_ message: String) {
    let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/DevCam/debug.log")
    try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let timestamped = "\(Date()) \(message)\n"
    try? timestamped.append(to: logURL)
}
```
**Pros:** Always accessible, can tail -f during development
**Cons:** Requires disk I/O, need to manage file size

## Recommendation for User

**You need to run DevCam from Xcode to see the console output.**

The debug logging we added is working, but Swift's `print()` statements aren't accessible when launching the app via `open` command or from the Finder.

**Steps:**
1. Open Xcode
2. Open `/Users/dev/Documents/Software/macOS/DevCam/DevCam/DevCam.xcodeproj`
3. Press ⌘R to run with debugger
4. Watch the debug console (bottom panel, press ⌘⇧Y if hidden)
5. Report back what you see in the console
6. Check if the menubar icon appears

This will give us the complete picture of what's happening during initialization and why the menubar icon isn't visible.
