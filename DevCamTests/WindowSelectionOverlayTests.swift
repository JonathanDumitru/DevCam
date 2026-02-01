//
//  WindowSelectionOverlayTests.swift
//  DevCamTests
//
//  Tests for WindowSelectionOverlay view logic.
//

import XCTest
@testable import DevCam

final class WindowSelectionOverlayTests: XCTestCase {

    // MARK: - Coordinate Conversion Tests

    func testConvertToOverlayFrameFlipsYCoordinate() {
        // macOS screen coordinates: origin at bottom-left
        // SwiftUI GeometryReader: origin at top-left
        // A window at the bottom of the screen in macOS coordinates
        // should appear at the top in SwiftUI coordinates

        let windowFrame = CGRect(x: 100, y: 50, width: 400, height: 300)
        let overlaySize = CGSize(width: 1920, height: 1080)
        let screenHeight: CGFloat = 1080

        let converted = WindowSelectionOverlayHelpers.convertToOverlayFrame(
            windowFrame,
            in: overlaySize,
            screenHeight: screenHeight
        )

        // Window maxY in macOS = 350 (50 + 300)
        // Flipped Y = screenHeight - maxY = 1080 - 350 = 730
        XCTAssertEqual(converted.origin.x, 100)
        XCTAssertEqual(converted.origin.y, 730)
        XCTAssertEqual(converted.width, 400)
        XCTAssertEqual(converted.height, 300)
    }

    func testConvertToOverlayFrameAtTopOfScreen() {
        // Window at top of screen in macOS (high Y value)
        let windowFrame = CGRect(x: 0, y: 780, width: 1920, height: 300)
        let overlaySize = CGSize(width: 1920, height: 1080)
        let screenHeight: CGFloat = 1080

        let converted = WindowSelectionOverlayHelpers.convertToOverlayFrame(
            windowFrame,
            in: overlaySize,
            screenHeight: screenHeight
        )

        // Window maxY in macOS = 1080, flipped Y = 0 (top in SwiftUI)
        XCTAssertEqual(converted.origin.y, 0)
    }

    func testConvertToOverlayFrameAtBottomOfScreen() {
        // Window at bottom of screen in macOS (low Y value)
        let windowFrame = CGRect(x: 0, y: 0, width: 1920, height: 100)
        let overlaySize = CGSize(width: 1920, height: 1080)
        let screenHeight: CGFloat = 1080

        let converted = WindowSelectionOverlayHelpers.convertToOverlayFrame(
            windowFrame,
            in: overlaySize,
            screenHeight: screenHeight
        )

        // Window maxY in macOS = 100, flipped Y = 980 (bottom in SwiftUI)
        XCTAssertEqual(converted.origin.y, 980)
    }

    // MARK: - Selection State Tests

    func testIsSelectedReturnsTrueWhenWindowInSelection() {
        let selections = [
            WindowSelection(windowID: 100, ownerName: "App1", windowTitle: "Title1", isPrimary: true),
            WindowSelection(windowID: 200, ownerName: "App2", windowTitle: "Title2", isPrimary: false)
        ]

        XCTAssertTrue(WindowSelectionOverlayHelpers.isSelected(windowID: 100, in: selections))
        XCTAssertTrue(WindowSelectionOverlayHelpers.isSelected(windowID: 200, in: selections))
    }

    func testIsSelectedReturnsFalseWhenWindowNotInSelection() {
        let selections = [
            WindowSelection(windowID: 100, ownerName: "App1", windowTitle: "Title1", isPrimary: true)
        ]

        XCTAssertFalse(WindowSelectionOverlayHelpers.isSelected(windowID: 999, in: selections))
    }

    func testIsSelectedReturnsFalseWhenSelectionEmpty() {
        let selections: [WindowSelection] = []

        XCTAssertFalse(WindowSelectionOverlayHelpers.isSelected(windowID: 100, in: selections))
    }

    func testIsPrimaryReturnsTrueOnlyForPrimaryWindow() {
        let selections = [
            WindowSelection(windowID: 100, ownerName: "App1", windowTitle: "Title1", isPrimary: true),
            WindowSelection(windowID: 200, ownerName: "App2", windowTitle: "Title2", isPrimary: false)
        ]

        XCTAssertTrue(WindowSelectionOverlayHelpers.isPrimary(windowID: 100, in: selections))
        XCTAssertFalse(WindowSelectionOverlayHelpers.isPrimary(windowID: 200, in: selections))
    }

    func testIsPrimaryReturnsFalseWhenWindowNotInSelection() {
        let selections = [
            WindowSelection(windowID: 100, ownerName: "App1", windowTitle: "Title1", isPrimary: true)
        ]

        XCTAssertFalse(WindowSelectionOverlayHelpers.isPrimary(windowID: 999, in: selections))
    }

    // MARK: - Selection Count Warning Tests

    func testShouldShowWarningWhenCountExceedsThreshold() {
        XCTAssertTrue(WindowSelectionOverlayHelpers.shouldShowWarning(selectedCount: 5, threshold: 4))
        XCTAssertTrue(WindowSelectionOverlayHelpers.shouldShowWarning(selectedCount: 10, threshold: 4))
    }

    func testShouldNotShowWarningWhenCountAtOrBelowThreshold() {
        XCTAssertFalse(WindowSelectionOverlayHelpers.shouldShowWarning(selectedCount: 4, threshold: 4))
        XCTAssertFalse(WindowSelectionOverlayHelpers.shouldShowWarning(selectedCount: 3, threshold: 4))
        XCTAssertFalse(WindowSelectionOverlayHelpers.shouldShowWarning(selectedCount: 0, threshold: 4))
    }

    // MARK: - Selection Count Text Tests

    func testSelectionCountTextSingular() {
        XCTAssertEqual(
            WindowSelectionOverlayHelpers.selectionCountText(count: 1),
            "1 window selected"
        )
    }

    func testSelectionCountTextPlural() {
        XCTAssertEqual(
            WindowSelectionOverlayHelpers.selectionCountText(count: 0),
            "0 windows selected"
        )
        XCTAssertEqual(
            WindowSelectionOverlayHelpers.selectionCountText(count: 3),
            "3 windows selected"
        )
        XCTAssertEqual(
            WindowSelectionOverlayHelpers.selectionCountText(count: 10),
            "10 windows selected"
        )
    }

    // MARK: - Warning Text Tests

    func testWarningTextForHighWindowCount() {
        XCTAssertEqual(
            WindowSelectionOverlayHelpers.warningText(count: 5),
            "5+ may affect quality"
        )
        XCTAssertEqual(
            WindowSelectionOverlayHelpers.warningText(count: 8),
            "8+ may affect quality"
        )
    }
}
