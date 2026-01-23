# Preferences Window Crash Fix - 2026-01-23

## Problem

**Symptom:** Application crashes when clicking "Preferences..." button from menubar dropdown, with error "memory read failed for 0x17" in Xcode debugger.

**Timing:** Crash occurs after app has been running for several minutes (observed at 9 minutes in crash report).

**User Report:** "this was when i clicked on the menubar icon for our app, then clicked on preferences. the app ran into a freezestate giving me that error in xcode prior to code cleanup"

## Root Cause Analysis

### Crash Report Details

**Latest Crash:** DevCam-2026-01-23-112852.ips
- **Launch Time:** 11:19:25 AM
- **Crash Time:** 11:28:49 AM (9 minutes later)
- **Exception:** `EXC_BAD_ACCESS (SIGSEGV)` - Null pointer dereference at address 0x0
- **Crash Location:** objc_msgSend → swift_getObjectType → MainActor.assumeIsolated → _ButtonGesture

### Stack Trace Analysis

```
objc_msgSend+56
→ swift_getObjectType+204
→ swift_task_isMainExecutorImpl+36
→ MainActor.assumeIsolated+88
→ closure #1 in _ButtonGesture.internalBody.getter+120
→ [Button gesture handling in SwiftUI]
```

**What this means:**
1. User clicked a button (in Preferences window)
2. SwiftUI's button gesture handler triggered
3. MainActor tried to verify isolation (for @MainActor code)
4. objc_msgSend tried to get object type
5. **CRASH:** Object was nil/invalid (address 0x0)

### The "Memory Read Failed for 0x17" Error

Address `0x17` (decimal 23) is a small offset from null (0x0). This indicates:
- We have a null pointer
- Code tried to access a field at offset 23 bytes into the object
- The memory access failed because there's no valid object

This is consistent with accessing an @ObservedObject property that has become nil/invalid.

## The Bug

### Architecture

```
AppDelegate
├── settings: AppSettings!                    (implicitly unwrapped optional)
├── clipExporter: ClipExporter!               (implicitly unwrapped optional)
├── preferencesWindow: NSWindow? (CACHED)     (regular optional)
    └── contentView: NSHostingView
        └── PreferencesWindow (SwiftUI)
            ├── @ObservedObject settings
            ├── @ObservedObject permissionManager
            └── @ObservedObject clipExporter
                └── ClipsTab
                    └── @ObservedObject clipExporter
                        └── Buttons that call clipExporter methods
```

### The Problem

1. **First click on "Preferences...":**
   - `showPreferences()` creates PreferencesWindow with valid manager references
   - Window is cached in `preferencesWindow` property
   - Window displays correctly

2. **Later usage (or second click):**
   - Cached window is reused (line 264 check: `if preferencesWindow == nil`)
   - SwiftUI views inside (PreferencesWindow, ClipsTab, etc.) retain references to managers
   - **BUT:** `@ObservedObject` does NOT strongly retain the object
   - If manager objects become invalid (memory corruption, deallocation, etc.), the view's reference becomes stale

3. **Crash trigger:**
   - User clicks button in ClipsTab (e.g., "Clear All", "Delete", "Show in Finder")
   - SwiftUI tries to access `clipExporter.recentClips` or call a method
   - clipExporter reference is invalid → null pointer dereference → CRASH

### Why Managers Become Invalid

Possible causes:
1. **Memory corruption** - Some other code overwrites manager memory
2. **Premature deallocation** - Despite AppDelegate retaining them, ARC issues could cause release
3. **@ObservedObject weakness** - SwiftUI's @ObservedObject wrapper doesn't create strong reference
4. **Stale view references** - Cached window retains old view hierarchy with old object references

## The Fix

### Solution: Always Recreate Preferences Window

Instead of caching the window and reusing it, **recreate it every time** with fresh manager references.

### Code Changes

**File:** `DevCamApp.swift`
**Function:** `showPreferences()`
**Lines:** 247-299

**Before (caching window):**
```swift
// Create window if needed
if preferencesWindow == nil {
    // Create PreferencesWindow with managers
    let prefsView = PreferencesWindow(
        settings: settings,
        permissionManager: permissionManager,
        clipExporter: clipExporter
    )
    // Create and cache NSWindow
    let window = NSWindow(...)
    window.contentView = NSHostingView(rootView: prefsView)
    preferencesWindow = window  // CACHE IT
}

// Reuse cached window
preferencesWindow?.makeKeyAndOrderFront(nil)
```

**After (always recreate):**
```swift
// CRITICAL FIX: Always recreate window with fresh manager references
// This prevents stale @ObservedObject references from causing crashes
print("🪟 DEBUG: Closing existing preferences window if present")
preferencesWindow?.close()
preferencesWindow = nil

print("🪟 DEBUG: Creating new preferences window with fresh manager references")
let prefsView = PreferencesWindow(
    settings: settings,
    permissionManager: permissionManager,
    clipExporter: clipExporter
)

let window = NSWindow(...)
window.contentView = NSHostingView(rootView: prefsView)
preferencesWindow = window

// Show newly created window
window.makeKeyAndOrderFront(nil)
```

### Why This Works

1. **Fresh References:** Every time Preferences opens, we create new PreferencesWindow with current manager references
2. **Clean State:** Old window is explicitly closed and deallocated before creating new one
3. **No Stale Pointers:** SwiftUI views always have valid @ObservedObject references from creation time
4. **Fail-Safe:** Guards still validate managers before window creation

### Trade-offs

**Pros:**
- ✅ Eliminates stale reference crashes
- ✅ Ensures fresh UI state every time
- ✅ Simple, reliable fix
- ✅ No complex lifecycle management

**Cons:**
- ❌ Slight performance overhead (recreating window/views)
- ❌ Window position not preserved between opens
- ❌ Tab selection resets to first tab

**Verdict:** For a Preferences window that's opened infrequently, the pros vastly outweigh the cons.

## Verification Steps

### Build Status
✅ Build succeeded with fix applied

### Testing Required

1. **Launch DevCam from Xcode (⌘R)**
2. **Wait for initialization** - Watch console for manager setup
3. **Open Preferences** - Click menubar icon → "Preferences..."
   - Expected: Window opens without crash
   - Check: Console shows "Creating new preferences window with fresh manager references"
4. **Close Preferences** - Click red X or close button
5. **Open Preferences AGAIN** - Test cached window scenario
   - Expected: Window recreates (console shows fresh creation)
   - Expected: No crash
6. **Click buttons in Clips tab** - If there are clips, test "Clear All", delete, etc.
   - Expected: Buttons work without crashing
   - Check: clipExporter methods execute successfully
7. **Leave app running for 10+ minutes**
8. **Repeat Preferences open/close cycle**
   - Expected: No "memory read failed" errors
   - Expected: No crashes

### Expected Console Output

```
🪟 DEBUG: showPreferences() - Opening preferences window
🪟 DEBUG: Checking manager initialization...
🪟 DEBUG: settings = initialized
🪟 DEBUG: clipExporter = initialized
🪟 DEBUG: Closing existing preferences window if present
🪟 DEBUG: Creating new preferences window with fresh manager references
✅ DEBUG: PreferencesWindow view created
🪟 DEBUG: Creating NSWindow
✅ DEBUG: NSWindow created
🪟 DEBUG: Setting NSHostingView as content view
✅ DEBUG: NSHostingView set
✅ DEBUG: Preferences window created and assigned
🪟 DEBUG: Calling makeKeyAndOrderFront
✅ DEBUG: Preferences window should now be visible
```

## Related Issues

### Issue #1: Menubar Icon Visibility (Still Unresolved)
- Status item created successfully but not visible
- Prevents testing without Xcode debugger

### Issue #2: No Video Recording (Still Unresolved)
- Buffer directory empty
- ScreenCaptureKit stream may be failing silently

### Issue #3: Memory Leak (Mentioned but not captured)
- User saw memory leak warning in Xcode
- Need to run with Instruments to identify

## Technical Debt Addressed

### Implicitly Unwrapped Optionals

**Current (risky):**
```swift
private var settings: AppSettings!
private var clipExporter: ClipExporter!
```

**Recommended (safer):**
```swift
private var settings: AppSettings?
private var clipExporter: ClipExporter?
```

This would require updating all access sites with optional chaining, but would prevent force-unwrap crashes.

### Window Caching Strategy

For apps with multiple auxiliary windows (like Preferences), consider:
1. **No caching** - Always recreate (current fix)
2. **Explicit refresh** - Cache window but refresh content view when shown
3. **Strong manager retention** - Use @StateObject instead of @ObservedObject
4. **Notification-based updates** - Managers post notifications, views observe

## Key Learnings

### 1. @ObservedObject vs @StateObject

**@ObservedObject:**
- Does NOT retain the object
- Expects parent to keep it alive
- Becomes invalid if underlying object is deallocated
- **Use for:** Passing existing objects down the view hierarchy

**@StateObject:**
- DOES retain the object
- Creates strong reference
- Owns the lifecycle of the object
- **Use for:** Creating and owning objects within a view

### 2. SwiftUI View Lifecycle

- SwiftUI may cache views and reuse them
- Cached views retain their @ObservedObject references
- If parent recreates manager objects, cached views have stale references
- Always pass fresh references or use @StateObject for ownership

### 3. Debugging Memory Issues

**"Memory read failed for 0xNN" in Xcode means:**
- Trying to access memory at address 0xNN
- If NN is small (< 1000), likely offset from null pointer
- If NN is large, likely accessing freed memory

**Tools to use:**
- Xcode Memory Graph Debugger
- Instruments → Leaks template
- Instruments → Allocations template
- Console.app for system logs
- Crash reports (.ips files) for stack traces

## Next Steps

1. **User Testing**
   - Run from Xcode
   - Test Preferences window open/close cycle
   - Verify no crashes when clicking buttons in tabs
   - Leave running for 10+ minutes and retest

2. **If Crash Persists**
   - Check for new crash reports
   - Capture full console output from Xcode
   - Run with Memory Graph Debugger enabled
   - Check for retain cycles or premature manager deallocation

3. **Long-term Fix**
   - Consider converting implicitly unwrapped optionals to regular optionals
   - Evaluate @StateObject for manager ownership
   - Add unit tests for manager lifecycle
   - Document manager initialization order and dependencies

## Summary

**Problem:** Preferences window crash due to stale @ObservedObject references in cached window.

**Fix:** Always recreate Preferences window with fresh manager references instead of caching.

**Status:** ✅ Built successfully, awaiting user verification.

**Impact:** Should eliminate the "memory read failed for 0x17" crash when opening Preferences.
