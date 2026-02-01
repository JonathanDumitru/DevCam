# Guided Walkthrough Design

**Date:** 2026-01-31
**Status:** Ready for implementation

## Overview

Add a two-part guided walkthrough that teaches users the DevCam interface during and immediately after onboarding.

## Goals

- Build user confidence before they're "on their own"
- Teach the menubar UI without requiring real recording
- Reinforce learning with a post-onboarding tooltip

## Design

### Part 1: Interface Tour Page (New Onboarding Page)

A new page inserted into the onboarding flow that shows a visual mockup of the menubar dropdown with interactive hotspots.

**Updated onboarding page order:**
1. Welcome
2. How It Works
3. Permission
4. **Interface Tour (NEW)**
5. Ready (renumbered)

**Visual layout:**
- Static SwiftUI mockup of the menubar dropdown (~220px wide)
- Centered in the 500x400 onboarding window
- Room for tooltips around the mockup

**Interactive hotspots (4 elements):**

| Element | Tooltip |
|---------|---------|
| Status indicator (red dot + "Recording") | "Shows recording status. Red means DevCam is capturing." |
| Buffer bar | "Shows how much is buffered. You can save up to 15 minutes." |
| Save Clip slider + button | "Drag to choose duration, then click Save Clip." |
| Display picker | "Switch which display to record." |

**Interaction model:**
- Hotspots have subtle pulsing glow to indicate they're tappable
- Clicking a hotspot shows its tooltip (replaces any visible tooltip)
- Instruction at bottom: "Click each highlighted area to learn more"
- Progress indicator shows which hotspots have been viewed
- "Next" button always enabled (viewing all is encouraged, not required)

### Part 2: Post-Onboarding Menubar Coach Mark

A floating tooltip that appears near the real menubar icon after onboarding completes.

**Trigger:**
Immediately after user clicks "Get Started" and onboarding window closes.

**Visual design:**
- Floating popover-style tooltip
- Rounded rectangle with system material/blur background
- Small arrow pointing up toward menubar icon
- Text: "Click here anytime to save a clip"
- Subtle "Got it" dismiss link

**Positioning:**
Anchored below the DevCam menubar icon using `NSPanel` or positioned `NSWindow`.

**Dismissal behavior:**
- Auto-dismisses after 6 seconds
- Dismisses on any click (including menubar icon)
- Dismisses if user opens the actual menubar popover

**One-time only:**
Stores `HasSeenMenubarTip` in UserDefaults. Never appears again.

## Implementation

### New Files

| File | Purpose |
|------|---------|
| `UI/InterfaceTourPage.swift` | New onboarding page with mockup and hotspots |
| `UI/MenubarCoachMark.swift` | Post-onboarding tooltip window |

### Modified Files

| File | Changes |
|------|---------|
| `UI/OnboardingView.swift` | Add InterfaceTourPage as page 4, renumber Ready to page 5, update page indicators |
| `DevCamApp.swift` | Trigger coach mark after onboarding completes |

### New UserDefaults Keys

- `HasSeenMenubarTip` (Boolean) - Prevents repeat coach marks

### Dependencies

None. Uses standard SwiftUI and AppKit.

## Error Handling

**Interface Tour Page:**
- Rapid hotspot clicks: only most recent tooltip shows (no stacking)
- Tooltips persist until another hotspot clicked or user proceeds
- Works regardless of permission status

**Menubar Coach Mark:**
- If menubar icon not ready: delay up to 2 seconds, then skip
- If user quits before dismissal: no issue (flag set on appearance)
- Appears as floating panel, won't steal focus from other windows

**Onboarding re-entry:**
- Force-quit during onboarding: restart from page 1 on relaunch
- `HasCompletedOnboarding` set only on final "Get Started" click
- `HasSeenMenubarTip` set independently when coach mark appears

## Maintenance

If MenuBarView UI changes significantly, InterfaceTourPage mockup needs manual update. This is an acceptable trade-off vs. live screenshot complexity.

## Testing

Manual testing checklist:
- [ ] All 4 hotspots show correct tooltips
- [ ] Progress indicator updates as hotspots are viewed
- [ ] Can proceed without viewing all hotspots
- [ ] Coach mark appears after onboarding completes
- [ ] Coach mark auto-dismisses after 6 seconds
- [ ] Coach mark dismisses on click
- [ ] Coach mark only appears once (relaunch to verify)
- [ ] Works on first launch with no prior UserDefaults
