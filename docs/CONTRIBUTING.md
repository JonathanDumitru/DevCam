# Contributing to DevCam

Thanks for taking the time to contribute. This guide explains how to propose
changes and keep the project consistent.

Status: The GitHub repository and PR/issue workflow are coming soon.

## Before You Start
- Review docs/README.md and docs/ARCHITECTURE.md
- Check docs/ROADMAP.md and open issues (coming soon)
- Search existing issues and pull requests for duplicates (coming soon)

## Development Setup
Follow docs/BUILDING.md for prerequisites and build steps.

## Workflow
1. Fork the repository (coming soon).
2. Create a feature branch from main.
3. Make focused changes with tests.
4. Open a pull request with a clear description (coming soon).

## Branching Conventions
- main: stable, release-ready
- feature/*: new features
- fix/*: bug fixes
- docs/*: documentation updates

## Code Style
- Follow Swift naming conventions and SwiftUI best practices.
- Prefer small, focused types and functions.
- Avoid adding new dependencies unless strictly required.
- Keep files and folders organized by feature.

## Testing
- Run: xcodebuild test -scheme DevCam -destination 'platform=macOS'
- Add unit tests for new logic.
- Include manual test notes for UI changes.

## Documentation Updates
- Update docs when behavior or UI changes.
- Keep user docs aligned with actual UI labels.

## Pull Request Checklist
- Explain the problem and solution.
- Link related issues when possible (coming soon).
- Add or update tests where appropriate.
- Include screenshots for UI changes.

## Issue Reporting
Use GitHub issues (coming soon) and include:
- macOS version
- DevCam version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs from Console.app (filter for "DevCam") or `log show` output

## Security Issues
See docs/SECURITY.md for reporting vulnerabilities.
