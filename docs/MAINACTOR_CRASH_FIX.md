# MainActor Initialization Crash Fix - 2026-01-23

## Critical Discovery

**User Report:** "the first line that appears in the console is: 'DEBUG: PermissionManager.init() - Checking permission'"

This revealed the crash happens **during AppDelegate initialization**, BEFORE `applicationDidFinishLaunching()` is even called!

## The Problem

### Timeline of Events

1. **App launches**
2. **AppDelegate class created**
3. **Line 24 executes:** `private let permissionManager = PermissionManager()`
4. **PermissionManager.init() starts** - prints debug line
5. **CRASH:** "memory read failed for 0x17" on Task 2
6. **Never reaches** `applicationDidFinishLaunching()`

### Root Cause: MainActor Isolation During Class Initialization

```swift
// AppDelegate.swift - Line 22-24
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private let permissionManager = PermissionManager()  // ← CRASH HERE!
```

```swift
// PermissionManager.swift - Line 21-34
@MainActor  // ← THIS IS THE PROBLEM!
class PermissionManager: ObservableObject {
    @Published var hasScreenRecordingPermission: Bool = false

    init() {
        print("🔐 DEBUG: PermissionManager.init() - Checking permission")
        checkPermission()  // ← Tries to access @Published property on MainActor
        print("🔐 DEBUG: PermissionManager initialized...")
    }
```

### Why This Crashes

1. **PermissionManager is `@MainActor` isolated** - ALL code must run on MainActor
2. **AppDelegate initialization happens during app startup** - NOT guaranteed to be on MainActor
3. **Swift tries to switch to MainActor** for init() - creates Task 2 to run on MainActor
4. **During task switch, memory access fails** - "memory read failed for 0x17"
5. **Address 0x17 (decimal 23)** - small offset from null, trying to access MainActor context that doesn't exist yet

### Error Message Breakdown

- **"memory read failed for 0x17"** - Trying to read memory at address 23 (0x17 hex)
- **"Task 2"** - MainActor executor task trying to run PermissionManager.init()
- **"(lldb)"** - Debugger caught the crash

### Why MainActor Wasn't Ready

During `NSApplicationDelegate` class initialization:
- The app's MainActor executor may not be fully set up
- `@NSApplicationDelegateAdaptor` is creating AppDelegate
- Swift's concurrency runtime is still initializing
- Trying to access MainActor context from property initializer = CRASH

## The Fix

### Solution: Defer MainActor Work Until App Is Ready

**Before (crashes):**
```swift
@MainActor
class PermissionManager: ObservableObject {
    init() {
        // Implicitly isolated to MainActor
        checkPermission()  // ← Accesses @Published property
    }
}
```

**After (safe):**
```swift
@MainActor
class PermissionManager: ObservableObject {
    // Make init explicitly NOT isolated to MainActor
    nonisolated init() {
        print("🔐 DEBUG: PermissionManager.init() - Deferring permission check")
        // Don't access any @MainActor properties here!
    }

    // Call this later from MainActor context
    func initialize() {
        print("🔐 DEBUG: PermissionManager.initialize() - Checking permission on MainActor")
        checkPermission()  // ← Safe: we're on MainActor now
    }
}
```

### AppDelegate Changes

**Call `initialize()` from `applicationDidFinishLaunching()`:**

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("🚀 DEBUG: applicationDidFinishLaunching() STARTED")
    print("🚀 DEBUG: applicationDidFinishLaunching() STARTED")

    // Now we're DEFINITELY on MainActor - safe to initialize
    print("🚀 DEBUG: Initializing PermissionManager on MainActor")
    permissionManager.initialize()
    print("✅ DEBUG: PermissionManager initialized")

    // Rest of initialization...
    setupManagers()
    setupStatusItem()
    // ...
}
```

### Why This Works

1. **`nonisolated init()`** - Can be called from any context, doesn't access @MainActor state
2. **Initialization is just object creation** - No @Published property access
3. **`applicationDidFinishLaunching()` runs on MainActor** - Guaranteed by AppKit
4. **`initialize()` is MainActor-isolated** - Safe to access @Published properties
5. **No premature MainActor switching** - No Task 2 crash during class init

## Code Changes

### File: `PermissionManager.swift`

**Changed init from:**
```swift
init() {
    print("🔐 DEBUG: PermissionManager.init() - Checking permission")
    checkPermission()
    print("🔐 DEBUG: PermissionManager initialized - hasScreenRecordingPermission = \(hasScreenRecordingPermission)")
}
```

**To:**
```swift
// CRITICAL: init must NOT be isolated to MainActor because it's called during
// AppDelegate initialization, which may not be on MainActor yet.
// We'll check permission later in a MainActor context.
nonisolated init() {
    print("🔐 DEBUG: PermissionManager.init() - Deferring permission check")
    print("🔐 DEBUG: PermissionManager initialized - will check permission on main actor")
}

// Call this after initialization to actually check permission
func initialize() {
    print("🔐 DEBUG: PermissionManager.initialize() - Checking permission on MainActor")
    checkPermission()
    print("🔐 DEBUG: PermissionManager initialized - hasScreenRecordingPermission = \(hasScreenRecordingPermission)")
}
```

### File: `DevCamApp.swift`

**Added initialization call:**
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("🚀 DEBUG: applicationDidFinishLaunching() STARTED")
    print("🚀 DEBUG: applicationDidFinishLaunching() STARTED")
    DevCamLogger.app.info("Application launching")

    // Initialize permission manager (must be done on MainActor)
    print("🚀 DEBUG: Initializing PermissionManager on MainActor")
    permissionManager.initialize()
    print("✅ DEBUG: PermissionManager initialized")

    // Initialize managers (works in both normal and test mode)
    print("🚀 DEBUG: About to call setupManagers()")
    setupManagers()
    print("✅ DEBUG: setupManagers() COMPLETED")
    // ...
}
```

## Expected Console Output

### Before Fix (Crash)
```
🔐 DEBUG: PermissionManager.init() - Checking permission
(lldb)  ← CRASH before anything else prints
```

### After Fix (Success)
```
🔐 DEBUG: PermissionManager.init() - Deferring permission check
🔐 DEBUG: PermissionManager initialized - will check permission on main actor
2026-01-23 11:15:41.406 DevCam[18691:214061] 🚀 DEBUG: applicationDidFinishLaunching() STARTED
🚀 DEBUG: applicationDidFinishLaunching() STARTED
🚀 DEBUG: Initializing PermissionManager on MainActor
🔐 DEBUG: PermissionManager.initialize() - Checking permission on MainActor
🔐 DEBUG: checkPermission() called
🔐 DEBUG: Calling CGPreflightScreenCaptureAccess()
🔐 DEBUG: CGPreflightScreenCaptureAccess() returned: true
🔐 DEBUG: hasScreenRecordingPermission set to: true
🔐 DEBUG: PermissionManager initialized - hasScreenRecordingPermission = true
✅ DEBUG: PermissionManager initialized
🚀 DEBUG: About to call setupManagers()
⚙️ DEBUG: setupManagers() - Creating AppSettings
⚙️ DEBUG: AppSettings created: SUCCESS
💾 DEBUG: BufferManager.init() - Initializing
💾 DEBUG: Using default buffer directory: ~/Library/Application Support/DevCam/buffer
✅ DEBUG: Buffer directory created/verified
⚙️ DEBUG: BufferManager created: SUCCESS
⚙️ DEBUG: Creating RecordingManager
⚙️ DEBUG: RecordingManager created: SUCCESS
⚙️ DEBUG: Creating ClipExporter
⚙️ DEBUG: ClipExporter created: SUCCESS
✅ DEBUG: All managers initialized successfully
   settings: ✅
   bufferManager: ✅
   recordingManager: ✅
   clipExporter: ✅
🚀 DEBUG: Setting activation policy to .accessory
✅ DEBUG: Activation policy set
🚀 DEBUG: About to call setupStatusItem()
📍 DEBUG: setupStatusItem() - Creating status bar item
📍 DEBUG: NSStatusBar.system.statusItem returned: SUCCESS
✅ DEBUG: Status item fully configured
🚀 DEBUG: About to call setupKeyboardShortcuts()
✅ DEBUG: setupKeyboardShortcuts() COMPLETED
🚀 DEBUG: About to call startRecording()
🎬 DEBUG: startRecording() - Creating Task
✅ DEBUG: startRecording() call initiated (async)
🎉 DEBUG: applicationDidFinishLaunching() COMPLETED
```

## Build Status

✅ **BUILD SUCCEEDED**

## Technical Deep Dive

### Swift Concurrency and MainActor

**MainActor** is a global actor representing the main thread:
- All UI code must run on MainActor
- `@MainActor` classes have ALL methods/properties isolated to main thread
- Accessing MainActor code from other contexts triggers task switching

**Problem with property initializers:**
```swift
class MyDelegate {
    let manager = MainActorClass()  // ← Called during class creation
}
```

This runs during `MyDelegate.__allocating_init()`, which may NOT be on MainActor yet!

### The `nonisolated` Keyword

`nonisolated` opts out of actor isolation:
```swift
@MainActor
class MyClass {
    nonisolated init() {
        // Can be called from ANY context
        // CANNOT access @MainActor properties
    }

    func doWork() {
        // Automatically isolated to MainActor
        // CAN access @MainActor properties
    }
}
```

### Why This Pattern Is Safe

1. **Object creation** happens in `nonisolated init()` - no MainActor required
2. **Property initialization** deferred to `initialize()` - called on MainActor
3. **No cross-actor calls** during early startup - no Task 2 crashes
4. **Clear lifecycle** - init → applicationDidFinishLaunching → initialize

## Related Fixes Applied

### 1. MenuBarView Caching Fix
- Always recreate popover with fresh manager references
- Prevents stale @ObservedObject references

### 2. PreferencesWindow Caching Fix
- Always recreate window with fresh manager references
- Prevents stale @ObservedObject references

### 3. Manager Initialization Assertions
- Added nil checks after each manager creation
- Explicit logging of initialization success/failure

## Key Learnings

### 1. @MainActor Classes and Property Initializers Don't Mix

**Dangerous:**
```swift
class AppDelegate {
    let mainActorThing = MainActorClass()  // ← CRASH RISK!
}
```

**Safe:**
```swift
class AppDelegate {
    let mainActorThing: MainActorClass

    init() {
        mainActorThing = MainActorClass()  // Still risky
    }

    func applicationDidFinishLaunching() {
        mainActorThing.initialize()  // ← SAFE!
    }
}
```

### 2. Use `nonisolated init()` for Actor-Isolated Classes

If you have a `@MainActor` class that needs to be created early:
```swift
@MainActor
class EarlyClass {
    nonisolated init() {
        // Basic setup only
    }

    func finishInitialization() {
        // MainActor work here
    }
}
```

### 3. Task 2 Crashes = Actor Isolation Issues

When debugger shows:
- **"Task 2"** in crash report
- **"memory read failed"** at low address
- **Crash before main()** or early in startup

**Suspect:** MainActor or other actor isolation during initialization!

### 4. Debug Console First Line Matters

If the FIRST line in console is from inside a class:
- Crash happened BEFORE caller's code
- Likely during class initialization
- Check for `@MainActor` on that class

## Testing Verification

### Step 1: Launch Test
1. Run from Xcode (⌘R)
2. **Expected:** Full console output appears
3. **Expected:** `🚀 DEBUG: applicationDidFinishLaunching() STARTED` is visible
4. **Expected:** No `(lldb)` crash

### Step 2: Menubar Test
1. Click menubar icon
2. **Expected:** Popover appears
3. **Expected:** Console shows `🖱️ DEBUG: statusItemClicked()`
4. **Expected:** No crash

### Step 3: Preferences Test
1. Click "Preferences..." in menubar
2. **Expected:** Window opens
3. **Expected:** No crash
4. **Expected:** Console shows window creation logs

### Step 4: Long-Running Test
1. Leave app running for 10+ minutes
2. Repeat menubar and preferences tests
3. **Expected:** No crashes, no memory errors

## Summary

**Problem:** PermissionManager's `@MainActor` init() crashed during AppDelegate initialization because MainActor wasn't ready yet.

**Fix:** Made init() `nonisolated` and deferred MainActor work to `initialize()` called from `applicationDidFinishLaunching()`.

**Status:** ✅ Built successfully, ready for testing.

**Impact:** Should completely eliminate the startup crash and allow app to launch successfully.
