# Release Process

This document defines how DevCam releases are prepared, verified, and published.

## Purpose
- Ensure releases are stable and repeatable
- Keep change history accurate and user-facing notes clear
- Maintain security, privacy, and notarization requirements

Note: GitHub release steps apply once the repository is public (coming soon).

## Roles
- Release lead: owns the release checklist and final sign-off
- Reviewer: validates tests, docs, and UI changes

## Versioning
DevCam follows Semantic Versioning (MAJOR.MINOR.PATCH).

Tag format:
- vX.Y.Z (for example: v0.1.0)

## Release Types
- Patch: bug fixes, small improvements, no behavior changes
- Minor: new features or UI changes, backward-compatible
- Major: breaking changes or large rewrites

## Pre-Release Checklist

### Code and Docs
- Update docs/CHANGELOG.md
- Verify docs/README.md and user docs match current UI
- Confirm no new entitlements were added unintentionally

### Tests
- Run unit tests: xcodebuild test -scheme DevCam -destination 'platform=macOS'
- Run manual test checklist:
  - First-run permission flow
  - Buffer rotation over 20+ minutes
  - Export last 5/10/15 minutes
  - Preferences and shortcut changes

### Build Settings
- Confirm deployment target is macOS 12.3+
- Ensure Release configuration is selected
- Verify signing and capabilities are correct

## Changelog Release Flow (Keep a Changelog)
1. Move items from [Unreleased] to a new version section.
2. Add release date to the new version section.
3. Ensure sections are sorted under Added/Changed/Deprecated/Removed/Fixed/Security.
4. Update compare links at the bottom of docs/CHANGELOG.md.
5. Create a git tag matching the version (vX.Y.Z).
6. Reference the changelog in the GitHub release notes.

## Build and Package
1. Archive in Xcode (Release configuration)
2. Export a signed app
3. Create a DMG with hdiutil

Artifacts:
- DevCam.app (signed)
- DevCam.dmg
- Optional: SHA256 checksums for artifacts

## Notarization
1. Submit:
   - xcrun notarytool submit DevCam.dmg --apple-id ... --team-id ... --password ...
2. Wait for approval
3. Staple:
   - xcrun stapler staple DevCam.dmg
4. Verify:
   - spctl -a -vvv -t install DevCam.dmg

## Verification
- Install from DMG on a clean machine or user account
- Verify menubar icon and permission flow
- Save and open a sample clip
- Confirm logs are written as expected

## Publish
- Create GitHub release with tag vX.Y.Z
- Attach DMG and release notes
- Link to docs/CHANGELOG.md

## Post-Release
- Monitor issues and support requests
- Update docs/ROADMAP.md if priorities change
- Plan a patch release if hotfixes are needed

## Rollback
- Pull the release from distribution channels
- Document the rollback in the changelog
- Revert to the last stable tag and rebuild

## Appendix: Common Commands
```
# Build tests
xcodebuild test -scheme DevCam -destination 'platform=macOS'

# Create DMG
hdiutil create -volname DevCam -srcfolder DevCam.app -ov -format UDZO DevCam.dmg

# Notarize and staple
xcrun notarytool submit DevCam.dmg --apple-id ... --team-id ... --password ...
xcrun stapler staple DevCam.dmg
spctl -a -vvv -t install DevCam.dmg
```
