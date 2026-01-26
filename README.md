# DevCam - macOS Developer Body Camera

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**Never lose that perfect demo, bug reproduction, or tutorial moment again.**

DevCam is a native macOS menubar app that continuously records your screen in a rolling 15-minute buffer, letting you save any portion of the last 15 minutes retroactively with a single click. Perfect for developers who need to capture unexpected bugs, spontaneous demos, or teaching moments—without the overhead of manual recording.

## Why DevCam?

Ever wish you could hit "save" *after* something interesting happened on your screen? That's DevCam.

**The Problem:** Bugs appear and disappear. Perfect demos happen when you're not recording. Tutorial-worthy workflows emerge organically, but you didn't hit "record" in time.

**The Solution:** DevCam runs quietly in your menubar, continuously recording your screen at 60fps. When something worth keeping happens, use the menubar Save Clip slider for 1-15 minutes, or press `⌘⇧5`/`⌘⇧6`/`⌘⇧7` for 5/10/15 minutes (shortcuts work system-wide). DevCam instantly exports that timeframe to a file, then keeps recording.

**The Guarantee:** Everything stays on your Mac. Zero network connections. Zero telemetry. Zero cloud storage. Your screen recordings never leave your device.

## Features

- ✅ **Continuous 60fps screen recording** with automatic buffer management
- ✅ **Rolling 15-minute buffer** that self-manages disk space and memory
- ✅ **Retroactive save** for 1-15 minutes via menubar; shortcuts for 5/10/15 when active
- ✅ **Native macOS menubar app** built with Swift and SwiftUI
- ✅ **Preferences window** with clips browser and settings management
- ✅ **Recording quality selection** (Low/Medium/High)
- ✅ **System integration** handles sleep/wake events
- ✅ **Real-time export progress** with notifications on completion
- ✅ **100% local and private** - no network connections, no telemetry, no cloud
- ✅ **Minimal resource usage** - typically ~5% CPU and ~100-200MB RAM
- ✅ **Zero external dependencies** - pure Swift using Apple frameworks

## Quick Start

### System Requirements

- **macOS 13.0 or later (Ventura+)** (requires ScreenCaptureKit and ServiceManagement frameworks)
- **Screen Recording permission** (granted on first launch)
- **2+ GB free disk space** for buffer and saved clips

### Installation

Since DevCam has no releases yet, build from source:

```bash
git clone https://github.com/JonathanDumitru/devcam.git
cd devcam/DevCam
open DevCam.xcodeproj
```

Build in Xcode (`⌘B`) or run directly (`⌘R`). See [Building from Source](#building-from-source) below for detailed setup.

### First Launch

1. **Launch DevCam** - A menubar icon (⏺) appears in your menubar
2. **Grant permissions** - macOS prompts for Screen Recording permission
3. **Choose save location** - Select where clips are saved (defaults to `~/Movies/DevCam`)
4. **Recording starts automatically** - DevCam begins buffering immediately

### Saving Clips

**Keyboard Shortcuts (system-wide):**
- `⌘⇧5` - Save last 5 minutes
- `⌘⇧6` - Save last 10 minutes
- `⌘⇧7` - Save last 15 minutes
Shortcuts work from any application.

**Menubar Menu:**
- Click the DevCam menubar icon
- Use the Save Clip slider to choose 1-15 minutes, then click Save Clip
- Optional: click Advanced... for a custom start/end range
- Clips export with progress tracking and completion notifications

### Finding Your Clips

- **Finder:** Navigate to your configured save location (default: `~/Movies/DevCam`)
- **Preferences:** Open DevCam Preferences → "Clips" tab to browse and preview
- **Notifications:** Completion notifications confirm export success

## Usage

### Recording Behavior

DevCam starts recording automatically when launched and permissions are granted. Recording continues until you quit the app. The 15-minute rolling buffer self-manages disk space, automatically deleting the oldest segments as new ones are created.

### Exporting Clips

When you trigger a save (via shortcut or menubar), DevCam:

1. **Identifies segments** covering the requested timeframe (5, 10, or 15 minutes)
2. **Exports in background** using `AVAssetExportSession` with H.264 encoding
3. **Shows progress** in the menubar
4. **Notifies on completion**
5. **Continues recording** without interruption during export

Export filenames follow the pattern: `DevCam_YYYY-MM-DD_HH-mm-ss.mp4`

### System Integration

DevCam handles macOS system events:

- **Sleep/Wake:** Pauses recording on sleep, resumes on wake

### Preferences

Open Preferences from the menubar menu:

- **General Tab:** Configure save location, recording quality, launch at login (preference only), notification preferences
- **Clips Tab:** Browse, preview, and manage saved clips
- **Privacy Tab:** Screen recording permission status and privacy details

See [Settings Reference](docs/SETTINGS.md) for complete configuration options.

## Technical Details

### Architecture

DevCam uses a **segment-based buffer architecture** optimized for continuous recording:

- **60-second segments** stored as individual `.mp4` files in a temporary buffer directory
- **15 segments maximum** (15 minutes × 60 seconds), automatically rotating oldest segments
- **AVAssetWriter pipeline** handles encoding in real-time with minimal CPU overhead
- **RecordingManager** coordinates capture, segmentation, and buffer management
- **ClipExporter** handles clip creation by concatenating relevant segments

See [Architecture Guide](docs/ARCHITECTURE.md) for deep technical details.

### Video Encoding

- **Codec:** H.264 (AVVideoCodecH264) for broad compatibility
- **Frame Rate:** 60fps for smooth playback of fast screen changes
- **Bitrate:** ~16 Mbps for 1080p (calculated as `width × height × 0.15 × fps`)
- **Container:** MPEG-4 (`.mp4`) format
- **Audio:** No audio capture (screen recording only)

### Performance

Typical resource usage on a 2020+ Mac with 1080p display:

- **CPU:** ~5% during recording, ~10-15% during export
- **Memory:** ~200MB for app + buffer management
- **Disk I/O:** ~120 MB/minute written (60-second segments at ~16 Mbps)
- **Buffer Size:** ~1.8 GB for full 15-minute buffer

Performance scales with screen resolution. See [Architecture Guide](docs/ARCHITECTURE.md) for optimization details.

### Dependencies

DevCam has **zero external dependencies**. It uses only Apple-provided frameworks:

- **ScreenCaptureKit** - Screen capture and recording (macOS 12.3+)
- **AVFoundation** - Video encoding and export
- **SwiftUI** - User interface
- **AppKit** - Menubar integration and system events

## Documentation

### For Users

- [**Beta Testing Guide**](docs/BETA_TESTING.md) - Beta scope, known limitations, and reporting
- [**Known Issues**](docs/KNOWN_ISSUES.md) - Active issues and limitations
- [**Compatibility**](docs/COMPATIBILITY.md) - Supported macOS versions and hardware notes
- [**Diagnostics**](docs/DIAGNOSTICS.md) - Log collection and troubleshooting data
- [**Feedback Template**](docs/FEEDBACK_TEMPLATE.md) - Copy/paste report format
- [**Beta Release Notes**](docs/BETA_RELEASE_NOTES.md) - Current beta changes and focus areas
- [**User Guide**](docs/USER_GUIDE.md) - Complete usage instructions and workflows
- [**Keyboard Shortcuts**](docs/SHORTCUTS.md) - Quick reference for all shortcuts
- [**Settings Reference**](docs/SETTINGS.md) - Configuration options explained
- [**Troubleshooting**](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [**FAQ**](docs/FAQ.md) - Frequently asked questions
- [**Privacy Policy**](docs/PRIVACY.md) - Data handling and privacy guarantees

### For Developers

- [**Building from Source**](docs/BUILDING.md) - Setup and compilation instructions
- [**Architecture Guide**](docs/ARCHITECTURE.md) - System design and implementation deep dive
- [**Code Map**](docs/CODE_MAP.md) - File-to-responsibility index
- [**Flow Guides**](docs/flows/recording-lifecycle.md) - Recording lifecycle and [save clip](docs/flows/save-clip.md) walkthroughs
- [**Decision Records**](docs/decisions/0001-segmented-buffer.md) - Segmented buffer and [no audio](docs/decisions/0002-no-audio.md) decisions
- [**ScreenCaptureKit Integration**](docs/SCREENCAPTUREKIT.md) - Technical details of screen capture
- [**Contributing**](docs/CONTRIBUTING.md) - Development workflow and guidelines
- [**Roadmap**](docs/ROADMAP.md) - Planned features and future direction

### Project Information

- [**Changelog**](docs/CHANGELOG.md) - Version history and release notes
- [**Security Policy**](docs/SECURITY.md) - Reporting vulnerabilities
- [**Support**](docs/SUPPORT.md) - Getting help and community resources
- [**Release Process**](docs/RELEASE_PROCESS.md) - How releases are created and distributed

## Privacy & Security

**DevCam is 100% local and private.** Here's what that means:

✅ **No network connections** - DevCam never connects to the internet
✅ **No telemetry** - Zero analytics, crash reports, or usage tracking
✅ **No cloud storage** - All recordings stay on your Mac
✅ **No third-party services** - No external dependencies or SDKs
✅ **Open source** - Inspect the code yourself to verify these claims

### Required Permissions

DevCam requires **Screen Recording permission** to capture your screen. This is a macOS system permission that you grant explicitly on first launch.

**Why this permission?** Screen recording is DevCam's core functionality. Without it, the app cannot capture your screen.

**What DevCam can see:** Everything visible on your screen(s) while recording is active.

**What DevCam cannot see:** File contents not displayed on screen, passwords in password managers (unless you reveal them on screen), system-level UI elements macOS protects from capture.

See [Privacy Policy](docs/PRIVACY.md) for complete details on data handling and permissions.

## Requirements

### Runtime Requirements

- **macOS 12.3 or later** (Monterey, Ventura, Sonoma, Sequoia)
- **Screen Recording permission** granted via System Settings
- **2+ GB free disk space** for buffer and saved clips
- **Recommended:** 8+ GB RAM for smooth operation alongside other apps

### Development Requirements

- **Xcode 14.0 or later** (Xcode 15+ recommended)
- **Swift 5.9 or later** (included with Xcode)
- **macOS 12.3+ SDK** (included with Xcode)
- **Apple Developer account** (for code signing, optional for local builds)

## Building from Source

Since DevCam has no official releases yet, building from source is the only installation method.

### Clone the Repository

```bash
git clone https://github.com/JonathanDumitru/devcam.git
cd devcam/DevCam
```

### Open in Xcode

```bash
open DevCam.xcodeproj
```

### Build and Run

1. **Select the DevCam scheme** in Xcode's toolbar
2. **Choose your Mac** as the run destination (not "My Mac (Designed for iPad)")
3. **Build:** Press `⌘B` or Product → Build
4. **Run:** Press `⌘R` or Product → Run

Xcode handles code signing automatically for local development builds.

### Build Configuration

- **Debug builds:** Include logging and debug symbols (larger binary, verbose console output)
- **Release builds:** Optimized for performance (smaller binary, minimal logging)

For detailed setup instructions, troubleshooting, and distribution builds, see [Building from Source](docs/BUILDING.md).

## Contributing

Contributions are welcome! DevCam is in active development, and we appreciate bug reports, feature requests, and pull requests.

### Before Contributing

1. **Read the guidelines:** See [Contributing Guide](docs/CONTRIBUTING.md) for workflow details
2. **Check existing issues:** Your idea or bug may already be tracked
3. **Review the roadmap:** See [Roadmap](docs/ROADMAP.md) for planned features

### Development Workflow

1. **Fork and clone** the repository
2. **Create a feature branch** from `main`
3. **Make your changes** following the project's code style
4. **Run the test suite** to ensure no regressions
5. **Submit a pull request** with a clear description

### Testing

DevCam includes a comprehensive test suite covering core managers:

- `RecordingManagerTests.swift` - Recording and buffer management
- `ClipExporterTests.swift` - Clip export and progress tracking
- `BufferManagerTests.swift` - Segment rotation and cleanup
- `PermissionManagerTests.swift` - Screen recording permissions
- `ModelsTests.swift` - Clip and segment model formatting

Run tests in Xcode with `⌘U` or Product → Test.

See [Contributing Guide](docs/CONTRIBUTING.md) for detailed testing requirements.

## License

DevCam is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2026 DevCam Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

See the [LICENSE](LICENSE) file for full terms.

## Acknowledgments

DevCam is built with Apple's **ScreenCaptureKit** framework, introduced in macOS 12.3 (Monterey). ScreenCaptureKit provides high-performance, low-latency screen capture with modern APIs that replaced the deprecated `CGWindowListCreateImage` approach.

**Technology Stack:**
- **Swift** - Pure Swift implementation with no Objective-C bridging
- **SwiftUI** - Modern declarative UI for preferences and clip browser
- **AVFoundation** - Video encoding, export, and asset management
- **AppKit** - Menubar integration and system event handling

**Thanks to:**
- The macOS developer community for ScreenCaptureKit examples and best practices
- Apple's WWDC sessions on screen capture, AVFoundation, and performance optimization
- Early testers and contributors who helped shape DevCam's design

---

**Built with ❤️ for developers who need to capture the moment, not plan for it.**
