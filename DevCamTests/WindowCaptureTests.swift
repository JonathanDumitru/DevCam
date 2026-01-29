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

    func testCaptureModeCodable() throws {
        let original = CaptureMode.windows
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CaptureMode.self, from: encoded)
        XCTAssertEqual(original, decoded)
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

    func testWindowSelectionNotEqualDifferentID() {
        let selection1 = WindowSelection(
            windowID: 123,
            ownerName: "Safari",
            windowTitle: "Apple",
            isPrimary: true
        )
        let selection2 = WindowSelection(
            windowID: 456,
            ownerName: "Safari",
            windowTitle: "Apple",
            isPrimary: true
        )
        XCTAssertNotEqual(selection1, selection2)
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

    func testWindowSelectionArrayCodable() throws {
        let selections = [
            WindowSelection(windowID: 1, ownerName: "App1", windowTitle: "Title1", isPrimary: true),
            WindowSelection(windowID: 2, ownerName: "App2", windowTitle: "Title2", isPrimary: false)
        ]

        let encoded = try JSONEncoder().encode(selections)
        let decoded = try JSONDecoder().decode([WindowSelection].self, from: encoded)

        XCTAssertEqual(selections, decoded)
    }

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

        // Secondary should be in bottom-right corner (default first corner)
        let secondary = layout[200]!
        XCTAssertGreaterThan(secondary.minX, 1000) // Right side
        XCTAssertLessThan(secondary.minY, 300) // Bottom (CoreGraphics origin is bottom-left)
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

        // All four windows should have layouts
        XCTAssertNotNil(layout[100])
        XCTAssertNotNil(layout[200])
        XCTAssertNotNil(layout[300])
        XCTAssertNotNil(layout[400])
    }

    @MainActor
    func testCompositorSecondaryWindowSize() async {
        let compositor = WindowCompositor()
        compositor.outputSize = CGSize(width: 1920, height: 1080)

        let layout = compositor.calculateLayout(
            primaryWindowID: 100,
            secondaryWindowIDs: [200]
        )

        let secondary = layout[200]!

        // Secondary should be 25% of output size
        XCTAssertEqual(secondary.width, 1920 * 0.25, accuracy: 1.0)
        XCTAssertEqual(secondary.height, 1080 * 0.25, accuracy: 1.0)
    }

    @MainActor
    func testCompositorNoPrimaryWindow() async {
        let compositor = WindowCompositor()
        compositor.outputSize = CGSize(width: 1920, height: 1080)

        let layout = compositor.calculateLayout(
            primaryWindowID: nil,
            secondaryWindowIDs: [200, 300]
        )

        // Should still layout secondary windows
        XCTAssertEqual(layout.count, 2)
        XCTAssertNotNil(layout[200])
        XCTAssertNotNil(layout[300])
    }
}
