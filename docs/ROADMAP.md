# DevCam Roadmap

Last updated: 2026-01-23

This roadmap is directional and may change based on feedback and priorities.

## Principles
- Local-first: no network features by default
- Low overhead: minimal CPU, memory, and disk impact
- Clear controls: predictable UI and shortcuts
- Privacy by design: least-privilege permissions

## Now (0-3 months)

### Objective: Expand capture capabilities without sacrificing performance
Key Results:
- KR1: Idle recording CPU usage under 3% on modern Macs
- KR1a: M1 baseline stays <= 5% CPU average and <= 150 MB memory during a 15-minute run
- KR2: Audio sync within 100 ms on 10-minute exports
- KR3: Multi-display capture survives display changes without crashes
- KR4: Trim preview loads in under 5 seconds for 10-minute clips

Initiatives:
- Audio recording (system + mic)
- Clip trimming UI
- Multi-display selection
- Resolution selection (720p through native)
- Forward recording mode for longer-than-15-minute clips
- Adjustable buffer length options

## Next (3-6 months)

### Objective: Improve usability and export flexibility
Key Results:
- KR1: Permission completion rate > 90% on first run
- KR2: Time-to-first-export under 2 minutes for new users
- KR3: Export success rate > 99% for 5/10/15 minute clips
- KR4: Export presets reduce average file size by 30% without quality complaints
- KR5: Markers export with clip metadata in 95% of cases

Initiatives:
- Event markers (manual bookmarks)
- Export presets (resolution and bitrate)
- Improved onboarding flow

## Later (6+ months)

### Objective: Enable optional collaboration while preserving privacy
Key Results:
- KR1: Cloud sync is fully opt-in with explicit consent
- KR2: Shared clips honor access control without data leakage
- KR3: Crash-free session rate > 99.5% over 7 days

Initiatives:
- Optional cloud backup (explicit opt-in)
- Team sharing features

## Backlog Ideas
- Clip annotations
- Auto-tagging clips by app focus
- Export to GIF for short clips

## How to Propose Items
Provide:
- Problem statement
- Target users and impact
- Success metrics
- Risks and dependencies
- Rough effort estimate

## Review Cadence
Roadmap is reviewed quarterly and after major releases.
