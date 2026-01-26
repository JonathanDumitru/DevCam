# App Store Readiness Design

**Date:** 2026-01-26
**Goal:** Get DevCam through TestFlight beta, iterate based on feedback, then submit to the Mac App Store.

---

## Overview

DevCam is a macOS menubar app for continuous screen recording with a 15-minute rolling buffer. This document outlines the technical requirements, sandbox compatibility considerations, and optimization work needed for Mac App Store submission.

### Distribution Strategy

- **Target:** Mac App Store (sandboxed)
- **Approach:** TestFlight beta first, then App Store submission
- **Critical dependency:** Apple must approve `com.apple.security.device.screen-capture` entitlement exception

---

## Phase 1: App Store Technical Requirements

### 1.1 Entitlement Exception Request

Request approval for screen-capture entitlement in a sandboxed app:

- **URL:** https://developer.apple.com/contact/request/screen-capture
- **Required information:** App purpose, why screen capture is essential, privacy handling
- **Response time:** 1-4 weeks
- **Risk:** May be denied — would require pivot to direct distribution

### 1.2 Sandbox Entitlements

Add to `DevCam.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

The `user-selected.read-write` entitlement allows saving clips to the user-chosen location via file picker.

### 1.3 Privacy Manifest

Create `PrivacyInfo.xcprivacy` declaring:

- **Data collection:** None
- **Tracking:** No
- **Required reason APIs:** Declare any privacy-sensitive APIs used (e.g., UserDefaults for recent clips)

### 1.4 Privacy Policy

Create and host a privacy policy stating:

- No data collected, transmitted, or shared
- Screen recordings stay entirely on user's device
- No analytics, telemetry, or network connections
- Host on GitHub Pages or personal website

---

## Phase 2: Sandbox Compatibility

### 2.1 File System Access

| Feature | Current Behavior | Sandbox Solution |
|---------|------------------|------------------|
| Save location | User-chosen via file picker | Store security-scoped bookmark; persist across launches |
| Buffer directory | `~/Library/Application Support/DevCam/buffer/` | Works — app container is accessible |
| Recent clips | UserDefaults | Works — no filesystem impact |

### 2.2 System Features

| Feature | Sandbox Impact | Status |
|---------|----------------|--------|
| Screen recording (ScreenCaptureKit) | Requires entitlement exception | Request from Apple |
| Launch at Login (SMAppService) | Works in sandbox | No changes needed |
| Notifications | Standard API | No changes needed |

### 2.3 High-Risk: Global Keyboard Shortcuts

Global event monitors (`NSEvent.addGlobalMonitorForEvents`) may fail or require Accessibility permission in sandboxed apps.

**Testing required:**
- Build with sandbox entitlement
- Test if ⌘⇧5/6/7 work system-wide
- If not, consider: removing feature for App Store, or documenting Accessibility permission requirement

---

## Phase 3: TestFlight Preparation

### 3.1 App Store Connect Setup

- **Bundle ID:** `Jonathan-Hines-Dumitru.DevCam` (register in Developer portal)
- **App Name:** "DevCam" (check availability)
- **Category:** Utilities or Video
- **Age Rating:** 4+

### 3.2 TestFlight Metadata

- App icon (1024x1024)
- Beta description for testers
- Contact email
- Privacy policy URL

### 3.3 Build Process

1. Archive from Xcode (Product → Archive)
2. Upload via Xcode Organizer
3. Wait for processing (15-30 minutes)
4. External testers require TestFlight review (24-48 hours)

---

## Phase 4: Performance Optimization

### 4.1 Known Issue: Energy Spikes

**Symptom:** Brief energy spikes when opening Preferences or revealing files.

**Investigation approach:**
1. Profile with Instruments (Energy Log, Time Profiler, SwiftUI)
2. Check for synchronous work on main thread
3. Look for unnecessary view recreation

**Likely suspects:**
- SwiftUI Preferences window recreation
- Clips tab thumbnail generation
- NSWorkspace file reveal (expected, lower priority)

### 4.2 Quality Settings Validation

Test each quality setting and capture metrics:

| Quality | Scale | Expected Impact |
|---------|-------|-----------------|
| Low | 0.5x | Lower CPU/memory, smaller files |
| Medium | 0.75x | Baseline (current default) |
| High | 1.0x | Higher resource usage, larger files |

**Metrics to capture:** CPU average, memory peak, segment file sizes, energy impact.

---

## Implementation Checklist

### Phase 1: Immediate (Blockers)
- [ ] Submit entitlement exception request to Apple
- [ ] Create and host privacy policy
- [ ] Add sandbox entitlement to DevCam.entitlements
- [ ] Add file access entitlements (user-selected.read-write)
- [ ] Create PrivacyInfo.xcprivacy manifest
- [ ] Test sandbox build locally — verify all features work

### Phase 2: TestFlight Prep (While Waiting on Entitlement)
- [ ] Register Bundle ID in Apple Developer portal
- [ ] Create app record in App Store Connect
- [ ] Create 1024x1024 app icon (if not already done)
- [ ] Write beta description for testers
- [ ] Test global keyboard shortcuts in sandboxed build
- [ ] Archive and upload to TestFlight

### Phase 3: Beta Period
- [ ] Recruit testers (internal first, then external)
- [ ] Collect feedback on crashes, usability, missing features
- [ ] Profile performance with Instruments (energy, CPU, memory)
- [ ] Validate all three quality settings
- [ ] Fix issues found, iterate builds

### Phase 4: App Store Submission
- [ ] Screenshots (at least 1 required, recommend 3-5)
- [ ] App Store description, keywords, subtitle
- [ ] Finalize version number
- [ ] Submit for review

---

## Risk Summary

| Risk | Impact | Mitigation |
|------|--------|------------|
| Entitlement denied | Cannot use App Store | Pivot to notarized direct distribution |
| Global shortcuts fail in sandbox | Feature loss | Remove or require Accessibility permission |
| Save location breaks in sandbox | Cannot save clips | Implement security-scoped bookmarks |
| TestFlight review rejection | Delays beta | Address feedback, resubmit |

---

## Success Criteria

- [ ] Entitlement exception approved by Apple
- [ ] All features work in sandboxed build
- [ ] TestFlight beta running with external testers
- [ ] No critical bugs reported in beta
- [ ] Performance meets targets (≤5% CPU, ≤150MB memory)
- [ ] App Store submission approved
