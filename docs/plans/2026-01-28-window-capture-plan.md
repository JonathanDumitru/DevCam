# Window Capture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add window-specific capture with picture-in-picture layout, live switching, and seamless fallback to display capture.

**Architecture:** Introduce a WindowCaptureManager that manages SCWindow streams alongside the existing display capture. A WindowCompositor handles PiP layout composition. The system supports live switching between capture modes without interrupting the recording buffer.

**Tech Stack:** ScreenCaptureKit (SCWindow, SCStream), CoreImage (compositing), AVFoundation (video encoding), SwiftUI (overlay UI)

---

## Phase 1: Foundation

### Task 1: CaptureMode Enum and WindowSelection Model

**Files:**
- Create: `DevCam/DevCam/DevCam/Models/CaptureMode.swift`

**Step 1: Create the CaptureMode enum and WindowSelection struct**

```swift
//
//  CaptureMode.swift
//  DevCam
//
//  Capture mode selection and window selection models.
//

import Foundation
import CoreGraphics

/// Capture mode for recording
enum CaptureMode: String, Codable, Equatable {
    case display
    case windows

    var displayName: String {
        switch self {
        case .display: return "Display"
        case .windows: return "Windows"
        }
    }
}

/// Represents a selected window for capture
struct WindowSelection: Codable, Identifiable, Equatable {
    let windowID: CGWindowID
    let ownerName: String
    let windowTitle: String
    var isPrimary: Bool

    var id: CGWindowID { windowID }

    var displayName: String {
        if windowTitle.isEmpty {
            return ownerName
        }
        return "\(ownerName) - \(windowTitle)"
    }
}
```

**Step 2: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add DevCam/Models/CaptureMode.swift
git commit -m "feat(capture): add CaptureMode enum and WindowSelection model"
```

---

### Task 2: Add Capture Mode to AppSettings

**Files:**
- Modify: `DevCam/DevCam/DevCam/Core/AppSettings.swift`

**Step 1: Add capture mode and window selection storage**

Add after the frame rate settings section (around line 324):

```swift
// MARK: - Capture Mode Settings

@AppStorage("captureMode") var captureMode: CaptureMode = .display

@AppStorage("selectedWindowsData") private var selectedWindowsData: Data = Data()

var selectedWindows: [WindowSelection] {
    get {
        guard !selectedWindowsData.isEmpty,
              let windows = try? JSONDecoder().decode([WindowSelection].self, from: selectedWindowsData) else {
            return []
        }
        return windows
    }
    set {
        if let data = try? JSONEncoder().encode(newValue) {
            selectedWindowsData = data
            objectWillChange.send()
        }
    }
}

func updateWindowSelection(_ windows: [WindowSelection]) {
    selectedWindows = windows
}

func clearWindowSelection() {
    selectedWindows = []
}

/// Soft limit warning threshold for window count
let windowCountWarningThreshold: Int = 4
```

**Step 2: Add ShortcutAction for window selection**

Find the `ShortcutAction` enum (around line 186) and add a new case:

```swift
case selectWindows = "selectWindows"
```

Add to `displayName`:
```swift
case .selectWindows: return "Select Windows"
```

Add to `defaultKeyCode`:
```swift
case .selectWindows: return 13  // W key
```

Add to `exportDuration`:
```swift
case .selectWindows: return nil
```

**Step 3: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add DevCam/Core/AppSettings.swift
git commit -m "feat(settings): add capture mode and window selection storage"
```

---

### Task 3: WindowCaptureManager - Single Window Capture

**Files:**
- Create: `DevCam/DevCam/DevCam/Core/WindowCaptureManager.swift`

**Step 1: Create WindowCaptureManager with single window capture support**

```swift
//
//  WindowCaptureManager.swift
//  DevCam
//
//  Manages window-based screen capture using ScreenCaptureKit.
//

import Foundation
import ScreenCaptureKit
import CoreImage
import OSLog

@MainActor
class WindowCaptureManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var availableWindows: [SCWindow] = []
    @Published private(set) var selectedWindows: [WindowSelection] = []
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var captureError: Error?

    // MARK: - Capture State

    private var windowStreams: [CGWindowID: SCStream] = [:]
    private var streamOutputs: [CGWindowID: WindowStreamOutput] = [:]

    // MARK: - Callbacks

    var onFrameCaptured: ((CVPixelBuffer, CGWindowID) -> Void)?

    // MARK: - Configuration

    private let settings: AppSettings

    // MARK: - Initialization

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
    }

    // MARK: - Window Discovery

    func refreshAvailableWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )

            // Filter to normal windows (exclude menubar, dock, tooltips, etc.)
            availableWindows = content.windows.filter { window in
                // Exclude windows with no title from non-standard apps
                // Keep windows that are on-screen and have reasonable size
                window.frame.width >= 100 && window.frame.height >= 100
            }

            DevCamLogger.recording.debug("Found \(self.availableWindows.count) capturable windows")
        } catch {
            DevCamLogger.recording.error("Failed to get available windows: \(error.localizedDescription)")
            availableWindows = []
        }
    }

    // MARK: - Window Selection

    func selectWindow(_ window: SCWindow, asPrimary: Bool) {
        let selection = WindowSelection(
            windowID: window.windowID,
            ownerName: window.owningApplication?.applicationName ?? "Unknown",
            windowTitle: window.title ?? "",
            isPrimary: asPrimary
        )

        // If setting as primary, demote existing primary
        if asPrimary {
            selectedWindows = selectedWindows.map { existing in
                var updated = existing
                updated.isPrimary = false
                return updated
            }
        }

        // Add or update selection
        if let index = selectedWindows.firstIndex(where: { $0.windowID == window.windowID }) {
            selectedWindows[index] = selection
        } else {
            selectedWindows.append(selection)
        }

        // If this is the first window, make it primary
        if selectedWindows.count == 1 {
            selectedWindows[0].isPrimary = true
        }

        settings.updateWindowSelection(selectedWindows)
        checkWindowCountWarning()
    }

    func deselectWindow(_ windowID: CGWindowID) {
        selectedWindows.removeAll { $0.windowID == windowID }

        // If we removed the primary, promote the first remaining window
        if !selectedWindows.isEmpty && !selectedWindows.contains(where: { $0.isPrimary }) {
            selectedWindows[0].isPrimary = true
        }

        settings.updateWindowSelection(selectedWindows)
    }

    func setPrimaryWindow(_ windowID: CGWindowID) {
        selectedWindows = selectedWindows.map { selection in
            var updated = selection
            updated.isPrimary = (selection.windowID == windowID)
            return updated
        }
        settings.updateWindowSelection(selectedWindows)
    }

    func clearSelection() {
        selectedWindows = []
        settings.clearWindowSelection()
    }

    // MARK: - Capture Control

    func startCapture() async throws {
        guard !selectedWindows.isEmpty else {
            DevCamLogger.recording.warning("No windows selected for capture")
            return
        }

        await refreshAvailableWindows()

        for selection in selectedWindows {
            guard let window = availableWindows.first(where: { $0.windowID == selection.windowID }) else {
                DevCamLogger.recording.warning("Window \(selection.windowID) no longer available, skipping")
                continue
            }

            do {
                try await startStreamForWindow(window)
            } catch {
                DevCamLogger.recording.error("Failed to start capture for window \(selection.windowID): \(error.localizedDescription)")
            }
        }

        isCapturing = !windowStreams.isEmpty
    }

    func stopCapture() async {
        for (windowID, stream) in windowStreams {
            do {
                try await stream.stopCapture()
                DevCamLogger.recording.debug("Stopped capture for window \(windowID)")
            } catch {
                DevCamLogger.recording.error("Error stopping stream for window \(windowID): \(error.localizedDescription)")
            }
        }

        windowStreams.removeAll()
        streamOutputs.removeAll()
        isCapturing = false
    }

    // MARK: - Stream Management

    private func startStreamForWindow(_ window: SCWindow) async throws {
        let config = createStreamConfiguration(for: window)
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let output = WindowStreamOutput(windowID: window.windowID) { [weak self] buffer, windowID in
            self?.onFrameCaptured?(buffer, windowID)
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
        try await stream.startCapture()

        windowStreams[window.windowID] = stream
        streamOutputs[window.windowID] = output

        DevCamLogger.recording.info("Started capture for window: \(window.title ?? "Untitled") (\(window.windowID))")
    }

    private func createStreamConfiguration(for window: SCWindow) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        let scaleFactor = settings.effectiveRecordingQuality.scaleFactor
        config.width = Int(Double(window.frame.width) * scaleFactor)
        config.height = Int(Double(window.frame.height) * scaleFactor)
        config.minimumFrameInterval = settings.targetFrameRate.frameInterval
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.queueDepth = 5
        config.showsCursor = true

        return config
    }

    // MARK: - Window Lifecycle

    func handleWindowClosed(_ windowID: CGWindowID) async {
        // Stop stream for this window
        if let stream = windowStreams[windowID] {
            do {
                try await stream.stopCapture()
            } catch {
                DevCamLogger.recording.error("Error stopping stream for closed window: \(error.localizedDescription)")
            }
            windowStreams.removeValue(forKey: windowID)
            streamOutputs.removeValue(forKey: windowID)
        }

        // Remove from selection
        let wasPrimary = selectedWindows.first { $0.windowID == windowID }?.isPrimary ?? false
        selectedWindows.removeAll { $0.windowID == windowID }

        // Promote next window to primary if needed
        if wasPrimary && !selectedWindows.isEmpty {
            selectedWindows[0].isPrimary = true
        }

        settings.updateWindowSelection(selectedWindows)

        DevCamLogger.recording.info("Window \(windowID) closed, removed from capture")
    }

    // MARK: - Warnings

    private func checkWindowCountWarning() {
        if selectedWindows.count > settings.windowCountWarningThreshold {
            DevCamLogger.recording.warning("High window count (\(self.selectedWindows.count)) may affect performance")
        }
    }

    // MARK: - Helpers

    var primaryWindow: WindowSelection? {
        selectedWindows.first { $0.isPrimary }
    }

    var secondaryWindows: [WindowSelection] {
        selectedWindows.filter { !$0.isPrimary }
    }

    var windowCount: Int {
        selectedWindows.count
    }
}

// MARK: - Window Stream Output

private class WindowStreamOutput: NSObject, SCStreamOutput {
    let windowID: CGWindowID
    let onFrame: (CVPixelBuffer, CGWindowID) -> Void

    init(windowID: CGWindowID, onFrame: @escaping (CVPixelBuffer, CGWindowID) -> Void) {
        self.windowID = windowID
        self.onFrame = onFrame
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        onFrame(pixelBuffer, windowID)
    }
}
```

**Step 2: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add DevCam/Core/WindowCaptureManager.swift
git commit -m "feat(capture): add WindowCaptureManager for window-based capture"
```

---

### Task 4: Add Capture Mode Toggle to MenuBarView

**Files:**
- Modify: `DevCam/DevCam/DevCam/UI/MenuBarView.swift`

**Step 1: Add windowCaptureManager property**

Add after the existing properties (around line 13):

```swift
@ObservedObject var windowCaptureManager: WindowCaptureManager
```

**Step 2: Add capture mode section**

Add a new section after `statusSection` and before `saveActionsSection` (around line 28):

```swift
Divider()

// Capture mode
captureModeSection
```

**Step 3: Create the capture mode section view**

Add after the `statusSection` computed property:

```swift
// MARK: - Capture Mode Section

private var captureModeSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Capture Mode")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)

        VStack(spacing: 4) {
            // Display option
            Button(action: {
                settings.captureMode = .display
            }) {
                HStack {
                    Image(systemName: settings.captureMode == .display ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(settings.captureMode == .display ? .accentColor : .secondary)
                    Text("Display")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Windows option
            Button(action: {
                settings.captureMode = .windows
            }) {
                HStack {
                    Image(systemName: settings.captureMode == .windows ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(settings.captureMode == .windows ? .accentColor : .secondary)
                    Text("Windows")
                    if !windowCaptureManager.selectedWindows.isEmpty {
                        Text("(\(windowCaptureManager.selectedWindows.count))")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }

        // Select Windows button (when in windows mode)
        if settings.captureMode == .windows {
            Button(action: {
                openWindowSelectionOverlay()
            }) {
                HStack {
                    Text("Select Windows...")
                        .font(.system(size: 12))
                    Spacer()
                    Text("⌘⇧W")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Warning for high window count
            if windowCaptureManager.selectedWindows.count > settings.windowCountWarningThreshold {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 10))
                    Text("\(windowCaptureManager.selectedWindows.count) windows - quality may degrade")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 12)
            }
        }
    }
    .padding(.vertical, 4)
}

@State private var showWindowSelectionOverlay = false

private func openWindowSelectionOverlay() {
    // TODO: Implement in Phase 3
    DevCamLogger.recording.debug("Window selection overlay requested")
}
```

**Step 4: Update the settings property**

Add `settings` as a property if not already present:

```swift
let settings: AppSettings
```

**Step 5: Update the preview**

Update the #Preview to include the new dependencies.

**Step 6: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 7: Commit**

```bash
git add DevCam/UI/MenuBarView.swift
git commit -m "feat(ui): add capture mode toggle to MenuBarView"
```

---

### Task 5: Integrate WindowCaptureManager into DevCamApp

**Files:**
- Modify: `DevCam/DevCam/DevCam/DevCamApp.swift`

**Step 1: Add WindowCaptureManager property**

Add after the existing manager properties:

```swift
private var windowCaptureManager: WindowCaptureManager?
```

**Step 2: Initialize WindowCaptureManager in setupManagers()**

Add in `setupManagers()`:

```swift
windowCaptureManager = WindowCaptureManager(settings: settings)
```

**Step 3: Pass WindowCaptureManager to MenuBarView**

Update the MenuBarView initialization to include `windowCaptureManager`.

**Step 4: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add DevCam/DevCamApp.swift
git commit -m "feat(app): integrate WindowCaptureManager into app lifecycle"
```

---

### Task 6: Unit Tests for WindowSelection Model

**Files:**
- Create: `DevCam/DevCam/DevCamTests/WindowCaptureTests.swift`

**Step 1: Create test file**

```swift
import XCTest
@testable import DevCam

final class WindowCaptureTests: XCTestCase {

    // MARK: - CaptureMode Tests

    func testCaptureModeDisplayName() {
        XCTAssertEqual(CaptureMode.display.displayName, "Display")
        XCTAssertEqual(CaptureMode.windows.displayName, "Windows")
    }

    func testCaptureModeEquatable() {
        XCTAssertEqual(CaptureMode.display, CaptureMode.display)
        XCTAssertNotEqual(CaptureMode.display, CaptureMode.windows)
    }

    // MARK: - WindowSelection Tests

    func testWindowSelectionDisplayName() {
        let selection = WindowSelection(
            windowID: 123,
            ownerName: "Safari",
            windowTitle: "Apple",
            isPrimary: true
        )
        XCTAssertEqual(selection.displayName, "Safari - Apple")
    }

    func testWindowSelectionDisplayNameEmptyTitle() {
        let selection = WindowSelection(
            windowID: 123,
            ownerName: "Safari",
            windowTitle: "",
            isPrimary: false
        )
        XCTAssertEqual(selection.displayName, "Safari")
    }

    func testWindowSelectionIdentifiable() {
        let selection = WindowSelection(
            windowID: 456,
            ownerName: "Xcode",
            windowTitle: "Project",
            isPrimary: true
        )
        XCTAssertEqual(selection.id, 456)
    }

    func testWindowSelectionEquatable() {
        let selection1 = WindowSelection(
            windowID: 123,
            ownerName: "Safari",
            windowTitle: "Apple",
            isPrimary: true
        )
        let selection2 = WindowSelection(
            windowID: 123,
            ownerName: "Safari",
            windowTitle: "Apple",
            isPrimary: true
        )
        XCTAssertEqual(selection1, selection2)
    }

    func testWindowSelectionCodable() throws {
        let original = WindowSelection(
            windowID: 789,
            ownerName: "Terminal",
            windowTitle: "bash",
            isPrimary: false
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WindowSelection.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }
}
```

**Step 2: Run tests**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild test -project DevCam.xcodeproj -scheme DevCam -destination 'platform=macOS' -only-testing:DevCamTests/WindowCaptureTests 2>&1 | grep -E "(Test Case|passed|failed)"`
Expected: All tests pass

**Step 3: Commit**

```bash
git add DevCamTests/WindowCaptureTests.swift
git commit -m "test(capture): add WindowSelection model unit tests"
```

---

## Phase 2: Multi-Window & Compositor

### Task 7: WindowCompositor - PiP Layout Engine

**Files:**
- Create: `DevCam/DevCam/DevCam/Core/WindowCompositor.swift`

**Step 1: Create WindowCompositor**

```swift
//
//  WindowCompositor.swift
//  DevCam
//
//  Composites multiple window frames into a single PiP layout.
//

import Foundation
import CoreImage
import CoreGraphics
import OSLog

/// Corner positions for secondary windows
enum PiPCorner: CaseIterable {
    case bottomRight
    case bottomLeft
    case topLeft
    // topRight intentionally excluded (menubar area)

    var offset: (x: CGFloat, y: CGFloat) {
        switch self {
        case .bottomRight: return (1.0, 0.0)
        case .bottomLeft: return (0.0, 0.0)
        case .topLeft: return (0.0, 1.0)
        }
    }
}

@MainActor
class WindowCompositor: ObservableObject {

    // MARK: - Configuration

    private let secondaryWindowScale: CGFloat = 0.25
    private let edgePadding: CGFloat = 8.0
    private let stackGap: CGFloat = 4.0

    // MARK: - State

    private var latestFrames: [CGWindowID: CIImage] = [:]
    private let ciContext = CIContext()

    // MARK: - Output

    var outputSize: CGSize = CGSize(width: 1920, height: 1080)

    // MARK: - Frame Management

    func updateFrame(_ pixelBuffer: CVPixelBuffer, for windowID: CGWindowID) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        latestFrames[windowID] = ciImage
    }

    func clearFrame(for windowID: CGWindowID) {
        latestFrames.removeValue(forKey: windowID)
    }

    func clearAllFrames() {
        latestFrames.removeAll()
    }

    // MARK: - Compositing

    func compositeFrames(
        primaryWindowID: CGWindowID?,
        secondaryWindowIDs: [CGWindowID]
    ) -> CVPixelBuffer? {
        // If only primary, return it directly (scaled to output)
        if secondaryWindowIDs.isEmpty, let primaryID = primaryWindowID {
            return renderSingleWindow(primaryID)
        }

        // Composite multiple windows
        return renderPiPLayout(
            primaryWindowID: primaryWindowID,
            secondaryWindowIDs: secondaryWindowIDs
        )
    }

    // MARK: - Single Window Rendering

    private func renderSingleWindow(_ windowID: CGWindowID) -> CVPixelBuffer? {
        guard let sourceImage = latestFrames[windowID] else { return nil }

        // Scale to fill output size
        let scaleX = outputSize.width / sourceImage.extent.width
        let scaleY = outputSize.height / sourceImage.extent.height
        let scale = max(scaleX, scaleY)

        let scaledImage = sourceImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Center in output
        let offsetX = (outputSize.width - scaledImage.extent.width) / 2
        let offsetY = (outputSize.height - scaledImage.extent.height) / 2
        let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))

        return renderToPixelBuffer(centeredImage)
    }

    // MARK: - PiP Layout Rendering

    private func renderPiPLayout(
        primaryWindowID: CGWindowID?,
        secondaryWindowIDs: [CGWindowID]
    ) -> CVPixelBuffer? {
        var compositeImage: CIImage?

        // Start with black background
        let backgroundImage = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: outputSize))
        compositeImage = backgroundImage

        // Render primary window (full size)
        if let primaryID = primaryWindowID,
           let primarySource = latestFrames[primaryID] {
            let scaledPrimary = scaleToFit(primarySource, in: outputSize)
            compositeImage = scaledPrimary.composited(over: compositeImage!)
        }

        // Render secondary windows in corners
        let corners = PiPCorner.allCases
        var cornerStacks: [PiPCorner: [CIImage]] = [:]

        for (index, windowID) in secondaryWindowIDs.enumerated() {
            guard let sourceImage = latestFrames[windowID] else { continue }

            let corner = corners[index % corners.count]
            if cornerStacks[corner] == nil {
                cornerStacks[corner] = []
            }
            cornerStacks[corner]?.append(sourceImage)
        }

        // Render each corner's stack
        for (corner, images) in cornerStacks {
            var yOffset: CGFloat = 0

            for image in images {
                let pipImage = renderSecondaryWindow(image, at: corner, stackOffset: yOffset)
                compositeImage = pipImage.composited(over: compositeImage!)

                let scaledHeight = image.extent.height * secondaryWindowScale
                yOffset += scaledHeight + stackGap
            }
        }

        return renderToPixelBuffer(compositeImage!)
    }

    private func renderSecondaryWindow(_ image: CIImage, at corner: PiPCorner, stackOffset: CGFloat) -> CIImage {
        // Scale down
        let scaled = image.transformed(by: CGAffineTransform(scaleX: secondaryWindowScale, y: secondaryWindowScale))

        // Calculate position
        let (cornerX, cornerY) = corner.offset

        var x: CGFloat
        var y: CGFloat

        if cornerX == 0 {
            x = edgePadding
        } else {
            x = outputSize.width - scaled.extent.width - edgePadding
        }

        if cornerY == 0 {
            y = edgePadding + stackOffset
        } else {
            y = outputSize.height - scaled.extent.height - edgePadding - stackOffset
        }

        return scaled.transformed(by: CGAffineTransform(translationX: x, y: y))
    }

    // MARK: - Helpers

    private func scaleToFit(_ image: CIImage, in size: CGSize) -> CIImage {
        let scaleX = size.width / image.extent.width
        let scaleY = size.height / image.extent.height
        let scale = min(scaleX, scaleY)

        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let offsetX = (size.width - scaled.extent.width) / 2
        let offsetY = (size.height - scaled.extent.height) / 2

        return scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
    }

    private func renderToPixelBuffer(_ image: CIImage) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(outputSize.width),
            Int(outputSize.height),
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        guard let buffer = pixelBuffer else { return nil }

        ciContext.render(image, to: buffer)
        return buffer
    }

    // MARK: - Layout Calculation (for UI preview)

    func calculateLayout(
        primaryWindowID: CGWindowID?,
        secondaryWindowIDs: [CGWindowID]
    ) -> [CGWindowID: CGRect] {
        var layout: [CGWindowID: CGRect] = [:]

        // Primary window fills the frame
        if let primaryID = primaryWindowID {
            layout[primaryID] = CGRect(origin: .zero, size: outputSize)
        }

        // Secondary windows in corners
        let corners = PiPCorner.allCases
        var cornerStacks: [PiPCorner: Int] = [:]

        for (index, windowID) in secondaryWindowIDs.enumerated() {
            let corner = corners[index % corners.count]
            let stackIndex = cornerStacks[corner] ?? 0
            cornerStacks[corner] = stackIndex + 1

            let width = outputSize.width * secondaryWindowScale
            let height = outputSize.height * secondaryWindowScale
            let (cornerX, cornerY) = corner.offset

            var x: CGFloat
            var y: CGFloat

            if cornerX == 0 {
                x = edgePadding
            } else {
                x = outputSize.width - width - edgePadding
            }

            let stackOffset = CGFloat(stackIndex) * (height + stackGap)
            if cornerY == 0 {
                y = edgePadding + stackOffset
            } else {
                y = outputSize.height - height - edgePadding - stackOffset
            }

            layout[windowID] = CGRect(x: x, y: y, width: width, height: height)
        }

        return layout
    }
}
```

**Step 2: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add DevCam/Core/WindowCompositor.swift
git commit -m "feat(capture): add WindowCompositor for PiP layout"
```

---

### Task 8: Unit Tests for WindowCompositor Layout

**Files:**
- Modify: `DevCam/DevCam/DevCamTests/WindowCaptureTests.swift`

**Step 1: Add compositor layout tests**

```swift
// MARK: - WindowCompositor Layout Tests

@MainActor
func testCompositorSingleWindowLayout() async {
    let compositor = WindowCompositor()
    compositor.outputSize = CGSize(width: 1920, height: 1080)

    let layout = compositor.calculateLayout(
        primaryWindowID: 100,
        secondaryWindowIDs: []
    )

    XCTAssertEqual(layout.count, 1)
    XCTAssertEqual(layout[100], CGRect(x: 0, y: 0, width: 1920, height: 1080))
}

@MainActor
func testCompositorPiPLayoutTwoWindows() async {
    let compositor = WindowCompositor()
    compositor.outputSize = CGSize(width: 1920, height: 1080)

    let layout = compositor.calculateLayout(
        primaryWindowID: 100,
        secondaryWindowIDs: [200]
    )

    XCTAssertEqual(layout.count, 2)
    XCTAssertNotNil(layout[100])
    XCTAssertNotNil(layout[200])

    // Secondary should be in bottom-right corner
    let secondary = layout[200]!
    XCTAssertGreaterThan(secondary.minX, 1000) // Right side
    XCTAssertLessThan(secondary.minY, 100) // Bottom
}

@MainActor
func testCompositorPiPLayoutThreeWindows() async {
    let compositor = WindowCompositor()
    compositor.outputSize = CGSize(width: 1920, height: 1080)

    let layout = compositor.calculateLayout(
        primaryWindowID: 100,
        secondaryWindowIDs: [200, 300]
    )

    XCTAssertEqual(layout.count, 3)

    // First secondary in bottom-right, second in bottom-left
    let secondary1 = layout[200]!
    let secondary2 = layout[300]!

    XCTAssertGreaterThan(secondary1.minX, secondary2.minX) // First is on right
}

@MainActor
func testCompositorPiPLayoutFourWindows() async {
    let compositor = WindowCompositor()
    compositor.outputSize = CGSize(width: 1920, height: 1080)

    let layout = compositor.calculateLayout(
        primaryWindowID: 100,
        secondaryWindowIDs: [200, 300, 400]
    )

    XCTAssertEqual(layout.count, 4)

    // Three corners used (not top-right)
    let positions = [layout[200]!, layout[300]!, layout[400]!]
    let corners = positions.map { pos -> String in
        let isRight = pos.minX > 1000
        let isTop = pos.minY > 500
        return "\(isRight ? "right" : "left")-\(isTop ? "top" : "bottom")"
    }

    XCTAssertFalse(corners.contains("right-top"), "Top-right should be empty for menubar")
}
```

**Step 2: Run tests**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild test -project DevCam.xcodeproj -scheme DevCam -destination 'platform=macOS' -only-testing:DevCamTests/WindowCaptureTests 2>&1 | grep -E "(Test Case|passed|failed)"`
Expected: All tests pass

**Step 3: Commit**

```bash
git add DevCamTests/WindowCaptureTests.swift
git commit -m "test(capture): add WindowCompositor layout unit tests"
```

---

### Task 9: Integrate Compositor with WindowCaptureManager

**Files:**
- Modify: `DevCam/DevCam/DevCam/Core/WindowCaptureManager.swift`

**Step 1: Add WindowCompositor property and integration**

Add compositor property:
```swift
private let compositor = WindowCompositor()
```

Add callback for composited frames:
```swift
var onCompositedFrame: ((CVPixelBuffer) -> Void)?
```

Update `onFrameCaptured` to route through compositor:
```swift
onFrameCaptured = { [weak self] buffer, windowID in
    self?.handleCapturedFrame(buffer, from: windowID)
}
```

Add method:
```swift
private func handleCapturedFrame(_ buffer: CVPixelBuffer, from windowID: CGWindowID) {
    compositor.updateFrame(buffer, for: windowID)

    // Composite and emit
    let primaryID = primaryWindow?.windowID
    let secondaryIDs = secondaryWindows.map { $0.windowID }

    if let composited = compositor.compositeFrames(
        primaryWindowID: primaryID,
        secondaryWindowIDs: secondaryIDs
    ) {
        onCompositedFrame?(composited)
    }
}
```

**Step 2: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add DevCam/Core/WindowCaptureManager.swift
git commit -m "feat(capture): integrate WindowCompositor into WindowCaptureManager"
```

---

### Task 10: Connect Window Capture to RecordingManager

**Files:**
- Modify: `DevCam/DevCam/DevCam/Core/RecordingManager.swift`

**Step 1: Add WindowCaptureManager dependency**

Add property:
```swift
private var windowCaptureManager: WindowCaptureManager?
```

**Step 2: Add method to set window capture manager**

```swift
func setWindowCaptureManager(_ manager: WindowCaptureManager) {
    self.windowCaptureManager = manager

    // Subscribe to composited frames for window mode
    manager.onCompositedFrame = { [weak self] buffer in
        Task { @MainActor in
            self?.handleWindowCaptureFrame(buffer)
        }
    }
}

private func handleWindowCaptureFrame(_ buffer: CVPixelBuffer) {
    // TODO: Write to AVAssetWriter (same as display capture path)
    // This will be connected in Phase 2 completion
}
```

**Step 3: Update setupAndStartStream to check capture mode**

Modify `setupAndStartStream()` to branch based on capture mode:
```swift
private func setupAndStartStream() async throws {
    if settings.captureMode == .windows && windowCaptureManager != nil {
        try await setupWindowCapture()
    } else {
        try await setupDisplayCapture()
    }
}

private func setupWindowCapture() async throws {
    guard let manager = windowCaptureManager else {
        throw RecordingError.streamSetupFailed
    }

    try await manager.startCapture()
    try await startNewSegment()
    scheduleSegmentRotation()

    DevCamLogger.recording.info("Window capture started with \(manager.windowCount) windows")
}

private func setupDisplayCapture() async throws {
    // Move existing display capture code here
    let displays = try await getAvailableDisplays()
    // ... rest of existing code
}
```

**Step 4: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add DevCam/Core/RecordingManager.swift
git commit -m "feat(capture): connect WindowCaptureManager to RecordingManager"
```

---

## Phase 3: Selection Overlay

### Task 11: WindowSelectionOverlay View

**Files:**
- Create: `DevCam/DevCam/DevCam/UI/WindowSelectionOverlay.swift`

**Step 1: Create the overlay view**

```swift
//
//  WindowSelectionOverlay.swift
//  DevCam
//
//  Full-screen overlay for click-to-select window capture.
//

import SwiftUI
import ScreenCaptureKit
import AppKit

struct WindowSelectionOverlay: View {
    @ObservedObject var windowCaptureManager: WindowCaptureManager
    let onDismiss: () -> Void

    @State private var hoveredWindowID: CGWindowID?

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Window highlights
            ForEach(windowCaptureManager.availableWindows, id: \.windowID) { window in
                WindowHighlight(
                    window: window,
                    isSelected: isSelected(window.windowID),
                    isPrimary: isPrimary(window.windowID),
                    isHovered: hoveredWindowID == window.windowID,
                    onTap: { handleWindowTap(window) },
                    onCommandTap: { handleCommandTap(window) },
                    onHover: { hovering in
                        hoveredWindowID = hovering ? window.windowID : nil
                    }
                )
            }

            // Bottom toolbar
            VStack {
                Spacer()

                HStack {
                    // Selection count
                    Text("\(windowCaptureManager.selectedWindows.count) windows selected")
                        .foregroundColor(.white)

                    // Warning if too many
                    if windowCaptureManager.selectedWindows.count > 4 {
                        Label("Quality may degrade", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }

                    Spacer()

                    // Instructions
                    Text("Click to select • ⌘+Click to set primary")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    // Done button
                    Button("Done") {
                        onDismiss()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)

                    // Cancel button
                    Button("Cancel") {
                        windowCaptureManager.clearSelection()
                        onDismiss()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            Task {
                await windowCaptureManager.refreshAvailableWindows()
            }
        }
    }

    private func isSelected(_ windowID: CGWindowID) -> Bool {
        windowCaptureManager.selectedWindows.contains { $0.windowID == windowID }
    }

    private func isPrimary(_ windowID: CGWindowID) -> Bool {
        windowCaptureManager.selectedWindows.first { $0.windowID == windowID }?.isPrimary ?? false
    }

    private func handleWindowTap(_ window: SCWindow) {
        if isSelected(window.windowID) {
            windowCaptureManager.deselectWindow(window.windowID)
        } else {
            let isFirst = windowCaptureManager.selectedWindows.isEmpty
            windowCaptureManager.selectWindow(window, asPrimary: isFirst)
        }
    }

    private func handleCommandTap(_ window: SCWindow) {
        if isSelected(window.windowID) {
            windowCaptureManager.setPrimaryWindow(window.windowID)
        } else {
            windowCaptureManager.selectWindow(window, asPrimary: true)
        }
    }
}

struct WindowHighlight: View {
    let window: SCWindow
    let isSelected: Bool
    let isPrimary: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onCommandTap: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        GeometryReader { geo in
            let frame = windowFrame(in: geo.size)

            ZStack(alignment: .topLeading) {
                // Window border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 4 : 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.green.opacity(0.1) : Color.white.opacity(0.05))
                    )

                // Labels
                VStack(alignment: .leading, spacing: 4) {
                    if isSelected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            if isPrimary {
                                Text("PRIMARY")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Text(window.owningApplication?.applicationName ?? "Unknown")
                        .font(.caption.bold())
                        .foregroundColor(.white)

                    if let title = window.title, !title.isEmpty {
                        Text(title)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(8)
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .onTapGesture {
                if NSEvent.modifierFlags.contains(.command) {
                    onCommandTap()
                } else {
                    onTap()
                }
            }
            .onHover { hovering in
                onHover(hovering)
            }
        }
    }

    private var borderColor: Color {
        if isSelected {
            return isPrimary ? .blue : .green
        }
        return isHovered ? .white : .white.opacity(0.5)
    }

    private func windowFrame(in screenSize: CGSize) -> CGRect {
        // Convert window frame to overlay coordinates
        // Note: This is simplified - real implementation needs screen coordinate conversion
        return window.frame
    }
}
```

**Step 2: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add DevCam/UI/WindowSelectionOverlay.swift
git commit -m "feat(ui): add WindowSelectionOverlay for click-to-select"
```

---

### Task 12: Window Selection Overlay Presentation

**Files:**
- Modify: `DevCam/DevCam/DevCam/UI/MenuBarView.swift`
- Modify: `DevCam/DevCam/DevCam/DevCamApp.swift`

**Step 1: Add overlay presentation in DevCamApp**

Add method to present overlay as a full-screen window:
```swift
func showWindowSelectionOverlay() {
    guard let windowCaptureManager = windowCaptureManager else { return }

    let overlay = WindowSelectionOverlay(
        windowCaptureManager: windowCaptureManager,
        onDismiss: { [weak self] in
            self?.dismissWindowSelectionOverlay()
        }
    )

    let hostingView = NSHostingView(rootView: overlay)

    let window = NSWindow(
        contentRect: NSScreen.main?.frame ?? .zero,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    window.level = .floating
    window.isOpaque = false
    window.backgroundColor = .clear
    window.makeKeyAndOrderFront(nil)

    // Store reference to close later
    self.overlayWindow = window
}

private var overlayWindow: NSWindow?

private func dismissWindowSelectionOverlay() {
    overlayWindow?.close()
    overlayWindow = nil
}
```

**Step 2: Connect MenuBarView button**

Update `openWindowSelectionOverlay()` in MenuBarView to call the app delegate method.

**Step 3: Register keyboard shortcut**

Update ShortcutManager to handle `.selectWindows` action.

**Step 4: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add DevCam/UI/MenuBarView.swift DevCam/DevCamApp.swift
git commit -m "feat(ui): wire up window selection overlay presentation"
```

---

## Phase 4: Polish & Edge Cases

### Task 13: Display Fallback When All Windows Close

**Files:**
- Modify: `DevCam/DevCam/DevCam/Core/WindowCaptureManager.swift`
- Modify: `DevCam/DevCam/DevCam/Core/RecordingManager.swift`

**Step 1: Add fallback callback to WindowCaptureManager**

```swift
var onAllWindowsClosed: (() -> Void)?
```

Update `handleWindowClosed` to trigger fallback:
```swift
if selectedWindows.isEmpty {
    DevCamLogger.recording.info("All windows closed, triggering fallback")
    onAllWindowsClosed?()
}
```

**Step 2: Handle fallback in RecordingManager**

```swift
manager.onAllWindowsClosed = { [weak self] in
    Task { @MainActor in
        await self?.fallbackToDisplayCapture()
    }
}

private func fallbackToDisplayCapture() async {
    DevCamLogger.recording.info("Falling back to display capture")
    settings.captureMode = .display

    // Stop window capture, start display capture without breaking segment
    await windowCaptureManager?.stopCapture()
    try? await setupDisplayCapture()
}
```

**Step 3: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add DevCam/Core/WindowCaptureManager.swift DevCam/Core/RecordingManager.swift
git commit -m "feat(capture): add automatic fallback to display capture"
```

---

### Task 14: Performance Monitoring for Window Capture

**Files:**
- Modify: `DevCam/DevCam/DevCam/Core/WindowCaptureManager.swift`

**Step 1: Add frame rate monitoring**

```swift
private var frameCount: Int = 0
private var lastFrameRateCheck: Date = Date()
private let frameRateCheckInterval: TimeInterval = 10.0

private func checkFrameRate() {
    let now = Date()
    let elapsed = now.timeIntervalSince(lastFrameRateCheck)

    if elapsed >= frameRateCheckInterval {
        let fps = Double(frameCount) / elapsed
        let targetFps = Double(settings.targetFrameRate.rawValue)

        if fps < targetFps * 0.5 {
            DevCamLogger.recording.warning("Window capture frame rate degraded: \(Int(fps)) fps (target: \(Int(targetFps)))")
            // Could trigger notification here
        }

        frameCount = 0
        lastFrameRateCheck = now
    }
}
```

Call from frame handler.

**Step 2: Build to verify**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add DevCam/Core/WindowCaptureManager.swift
git commit -m "feat(capture): add frame rate monitoring for window capture"
```

---

### Task 15: Final Integration Tests

**Files:**
- Modify: `DevCam/DevCam/DevCamTests/WindowCaptureTests.swift`

**Step 1: Add integration tests**

```swift
// MARK: - Integration Tests

@MainActor
func testWindowSelectionPersistence() async {
    let settings = AppSettings()
    settings.clearWindowSelection()

    let windows = [
        WindowSelection(windowID: 1, ownerName: "App1", windowTitle: "Title1", isPrimary: true),
        WindowSelection(windowID: 2, ownerName: "App2", windowTitle: "Title2", isPrimary: false)
    ]

    settings.updateWindowSelection(windows)

    XCTAssertEqual(settings.selectedWindows.count, 2)
    XCTAssertEqual(settings.selectedWindows[0].windowID, 1)
    XCTAssertTrue(settings.selectedWindows[0].isPrimary)
}

@MainActor
func testCaptureModeToggle() async {
    let settings = AppSettings()

    settings.captureMode = .display
    XCTAssertEqual(settings.captureMode, .display)

    settings.captureMode = .windows
    XCTAssertEqual(settings.captureMode, .windows)
}
```

**Step 2: Run all tests**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild test -project DevCam.xcodeproj -scheme DevCam -destination 'platform=macOS' -only-testing:DevCamTests/WindowCaptureTests 2>&1 | grep -E "(Test Suite|passed|failed)"`
Expected: All tests pass

**Step 3: Commit**

```bash
git add DevCamTests/WindowCaptureTests.swift
git commit -m "test(capture): add window capture integration tests"
```

---

### Task 16: Final Build and Manual Testing

**Step 1: Full build**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild -project DevCam.xcodeproj -scheme DevCam -configuration Debug build 2>&1 | grep -E "(error:|warning:.*DevCam|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 2: Run all tests**

Run: `cd /Users/dev/Documents/Software/macOS/DevCam/DevCam && xcodebuild test -project DevCam.xcodeproj -scheme DevCam -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|Test Suite.*failed)"`

**Step 3: Manual testing checklist**

- [ ] Toggle between Display and Windows mode in menubar
- [ ] Open window selection overlay via menubar button
- [ ] Open window selection overlay via ⌘⇧W
- [ ] Select a single window (becomes primary)
- [ ] Select multiple windows (first is primary)
- [ ] ⌘+click to reassign primary
- [ ] Click selected window to deselect
- [ ] Verify soft limit warning appears after 4 windows
- [ ] Close a captured window, verify it's removed
- [ ] Close all captured windows, verify fallback to display
- [ ] Export a clip captured in window mode

**Step 4: Commit**

```bash
git add -A
git commit -m "feat(capture): complete window capture implementation

- Window-specific capture with PiP layout
- Click-to-select overlay (⌘⇧W)
- Live switching without buffer interruption
- Automatic fallback to display capture
- Soft limit warning for window count
- Performance monitoring"
```
