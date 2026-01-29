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
}
