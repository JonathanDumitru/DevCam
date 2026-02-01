# DevCam App Store Content

This document contains all text content needed for App Store Connect submission.

---

## App Information

**App Name:** DevCam

**Subtitle:** (30 characters max)
```
Retroactive Screen Recording
```

**Primary Category:** Developer Tools

**Secondary Category:** Utilities

---

## Description

### Promotional Text (170 characters max)
*This appears above your description and can be updated without a new app version.*

```
Never lose a bug reproduction, demo, or tutorial moment again. Save the last 15 minutes of your screen anytime.
```

### Full Description (4000 characters max)

```
DevCam is a developer-focused screen recorder that runs quietly in your menubar, continuously capturing your screen in a rolling 15-minute buffer. When something worth keeping happens—a perfect bug reproduction, an unexpected demo moment, or a workflow worth sharing—simply save a clip retroactively. No need to remember to hit "record" beforehand.

RETROACTIVE RECORDING
DevCam is always recording, so you never miss a moment. Encountered a hard-to-reproduce bug? Save the last 5, 10, or 15 minutes instantly. The buffer keeps rolling, automatically managing disk space so you never have to think about it.

INSTANT KEYBOARD SHORTCUTS
Save clips from any application with global shortcuts:
• ⌘⌥5 — Save last 5 minutes
• ⌘⌥6 — Save last 10 minutes
• ⌘⌥7 — Save last 15 minutes

ADVANCED CLIP EDITING
Need precise timing? Use the Advanced export window to:
• Trim clips with visual timeline
• Preview before exporting
• Add titles, notes, and tags for organization
• Choose exact start and end points

BUILT FOR DEVELOPERS
• 60fps smooth capture for fast UI changes
• High-quality H.264 encoding
• Minimal resource usage (~5% CPU)
• Multiple display support with quick switching
• Adaptive quality based on system load

100% PRIVATE & LOCAL
Your recordings never leave your Mac. DevCam has:
• No cloud storage or uploads
• No analytics or telemetry
• No account required
• No internet connection needed

All footage is stored locally in a temporary buffer, and saved clips go to a folder you choose. When you quit DevCam, the buffer is cleared.

THOUGHTFUL DESIGN
• Native macOS menubar app
• Clean preferences window with tabbed interface
• Clip browser to manage saved recordings
• Real-time export progress
• System notifications on completion
• Automatic pause/resume on sleep/wake
• Battery-aware recording options

PERFECT FOR
• Bug reproduction and QA workflows
• Recording unexpected demos
• Creating tutorials and documentation
• Pair programming sessions
• Technical support and troubleshooting
• Any moment you wish you'd been recording

DevCam requires Screen Recording permission to capture your screen. This permission is requested on first launch and can be managed in System Settings > Privacy & Security > Screen Recording.

Requires macOS 13.0 (Ventura) or later.
```

---

## Keywords (100 characters max, comma-separated)

```
screen recorder,developer tools,bug,demo,capture,retroactive,buffer,clip,recording,menubar
```

Alternative keyword sets to test:

```
screen recording,developer,QA,bug reproduction,demo capture,tutorial,clip,buffer,menubar,local
```

```
screen capture,developer tools,retroactive,recording buffer,clip export,bug tracking,demo,private
```

---

## What's New (Version 1.0)

```
Initial release of DevCam.

• Continuous 60fps screen recording with 15-minute rolling buffer
• Global keyboard shortcuts for instant clip saving (⌘⌥5/6/7)
• Advanced clip export with timeline trimming and preview
• Clip annotations with titles, notes, and tags
• Multi-display support with quick switching
• Adaptive quality based on system load
• Battery-aware recording modes
• Health dashboard with diagnostics
• 100% local and private—no cloud, no telemetry
```

---

## App Store Review Notes

*These notes are only visible to Apple reviewers and help explain your app's functionality.*

```
Thank you for reviewing DevCam.

ABOUT THE APP
DevCam is a screen recording utility designed for software developers. It continuously records the screen in a rolling 15-minute buffer, allowing users to save clips retroactively after something interesting happens (like a bug reproduction or demo moment).

SCREEN RECORDING PERMISSION
DevCam requires Screen Recording permission because continuous screen capture is its core functionality. The app:
- Records the user's selected display at 60fps
- Stores footage in a local rolling buffer (temporary files)
- Exports clips to a user-selected folder when requested
- Never transmits any data over the network

HOW TO TEST
1. Launch the app—it appears as a menubar icon
2. Grant Screen Recording permission when prompted
3. Let it record for 2-3 minutes
4. Click the menubar icon and use the Save Clip slider
5. Or press ⌘⌥5 to save the last 5 minutes
6. Check the saved clip in ~/Movies/DevCam/ (default location)

PRIVACY
- All recordings are stored locally on the user's Mac
- No data is collected, transmitted, or uploaded
- No analytics, crash reporting, or telemetry
- No account or sign-in required
- No internet connection required or used

The app is fully sandboxed with only the necessary entitlements:
- Screen Capture (for recording)
- Microphone (reserved for future audio capture; not used in current builds)
- User-Selected Files (for saving clips)

OPTIONAL MICROPHONE
Microphone capture is not implemented in current builds. The entitlement is reserved for future audio features.

Please let me know if you need any additional information or a demo video.
```

---

## Support URL Content Suggestion

If you need to create a support page, here's suggested content:

```markdown
# DevCam Support

## Frequently Asked Questions

### How do I grant Screen Recording permission?
1. Open System Settings
2. Go to Privacy & Security > Screen Recording
3. Enable the toggle for DevCam
4. Restart DevCam if it was already running

### Where are my clips saved?
By default, clips are saved to ~/Movies/DevCam/. You can change this in Preferences > General > Save Location.

### How much disk space does DevCam use?
The rolling buffer uses approximately 1.8 GB for 15 minutes of 1080p recording. Saved clips vary based on duration and resolution.

### Can I record multiple displays?
Yes. Use the display picker in the menubar or Preferences > Recording to select which display to record. Note: switching displays clears the current buffer.

### Does DevCam work with external displays?
Yes. DevCam supports any display connected to your Mac, including external monitors and Sidecar.

## Contact

For bug reports and feature requests, please open an issue on GitHub:
https://github.com/JonathanDumitru/devcam/issues

For other inquiries: [your-email@example.com]
```

---

## Privacy Policy URL Content Suggestion

```markdown
# DevCam Privacy Policy

Last updated: January 2026

## Overview

DevCam is designed with privacy as a core principle. The app operates entirely locally on your Mac and does not collect, transmit, or store any personal data.

## Data Collection

**DevCam does not collect any data.** Specifically:

- No personal information is collected
- No usage analytics or telemetry
- No crash reports sent to external servers
- No account or sign-in required
- No cookies or tracking

## Screen Recordings

Screen recordings captured by DevCam:
- Are stored locally on your Mac
- Are never uploaded or transmitted
- Are under your complete control
- Can be deleted at any time

The rolling buffer (temporary recording storage) is automatically cleared when you quit DevCam.

## Permissions

DevCam requires Screen Recording permission to function. This permission:
- Is requested on first launch
- Can be revoked at any time in System Settings
- Is used solely to capture your screen for local storage

Microphone permission is not requested in current builds; the entitlement is reserved for future audio features.

## Third Parties

DevCam does not integrate with any third-party services, SDKs, or analytics platforms.

## Contact

For privacy-related questions: [your-email@example.com]

## Changes

Any changes to this privacy policy will be posted on this page with an updated date.
```

---

## App Store Screenshots Suggestions

For Mac App Store, you need screenshots at one of these sizes:
- 1280 x 800
- 1440 x 900
- 2560 x 1600
- 2880 x 1800

### Recommended Screenshots (in order)

1. **Menubar + Save Clip**
   - Show the menubar dropdown with the Save Clip slider
   - Caption: "Save clips instantly from the menubar"

2. **Keyboard Shortcuts**
   - Visual showing ⌘⌥5/6/7 shortcuts
   - Caption: "Global shortcuts work from any app"

3. **Advanced Export**
   - Show the Advanced Clip Window with timeline
   - Caption: "Precise timeline trimming and preview"

4. **Preferences - General**
   - Show the preferences window
   - Caption: "Easy configuration and clip management"

5. **Clips Browser**
   - Show the Clips tab with saved recordings
   - Caption: "Browse and organize your clips"

6. **Privacy**
   - Show the Privacy tab or a graphic emphasizing local storage
   - Caption: "100% local. No cloud. No tracking."

---

## App Preview Video (Optional)

If you create an app preview video (15-30 seconds), suggested flow:

1. Show DevCam running in menubar (2s)
2. Do some activity on screen (3s)
3. Press ⌘⌥5 to save clip (2s)
4. Show export progress (2s)
5. Show saved clip in Finder (2s)
6. Show clip playing in QuickTime (3s)
7. End card: "Never miss a moment" (2s)
