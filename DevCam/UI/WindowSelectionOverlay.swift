//
//  WindowSelectionOverlay.swift
//  DevCam
//
//  Full-screen overlay for click-to-select window capture.
//

import SwiftUI
import ScreenCaptureKit
import AppKit

// MARK: - Helper Functions (Testable)

/// Helper functions for WindowSelectionOverlay, extracted for testability.
enum WindowSelectionOverlayHelpers {

    /// Converts CGWindowList coordinates (Quartz, origin at top-left) to SwiftUI overlay coordinates.
    /// - Parameters:
    ///   - windowFrame: The window frame from CGWindowListCopyWindowInfo (Quartz coordinates, origin at top-left).
    ///   - screenFrame: The main screen frame for reference.
    /// - Returns: The frame for use in SwiftUI's coordinate system.
    static func convertToOverlayFrame(
        _ windowFrame: CGRect,
        screenFrame: CGRect
    ) -> CGRect {
        // CGWindowListCopyWindowInfo returns coordinates in Quartz/Core Graphics space
        // which has origin at TOP-LEFT of the main display (same as SwiftUI)
        // No Y-flip needed! Just use the coordinates directly.
        //
        // For multi-monitor setups, windows on secondary monitors may have
        // coordinates outside the main screen bounds, but since our overlay
        // covers the main screen, we just use the frame as-is.

        return CGRect(
            x: windowFrame.origin.x,
            y: windowFrame.origin.y,
            width: windowFrame.width,
            height: windowFrame.height
        )
    }

    /// Checks if a window is currently selected.
    static func isSelected(windowID: CGWindowID, in selections: [WindowSelection]) -> Bool {
        selections.contains { $0.windowID == windowID }
    }

    /// Checks if a window is the primary selection.
    static func isPrimary(windowID: CGWindowID, in selections: [WindowSelection]) -> Bool {
        selections.first { $0.windowID == windowID }?.isPrimary ?? false
    }

    /// Determines if a warning should be shown for high window count.
    static func shouldShowWarning(selectedCount: Int, threshold: Int) -> Bool {
        selectedCount > threshold
    }

    /// Returns the selection count text with proper pluralization.
    static func selectionCountText(count: Int) -> String {
        count == 1 ? "1 window selected" : "\(count) windows selected"
    }

    /// Returns the warning text for high window counts.
    static func warningText(count: Int) -> String {
        "\(count)+ may affect quality"
    }
}

// MARK: - WindowSelectionOverlay View

struct WindowSelectionOverlay: View {
    // Use unowned reference to avoid retain cycles during teardown
    let windowCaptureManager: WindowCaptureManager
    let settings: AppSettings
    let onDismiss: () -> Void

    // Local state copies to avoid SwiftUI holding references to manager's published arrays
    @State private var localAvailableWindows: [AvailableWindow] = []
    @State private var localSelectedWindows: [WindowSelection] = []
    @State private var hoveredWindowID: CGWindowID?

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // Clicking on background does nothing (prevents accidental dismiss)
                }

            // Window highlights - positioned based on screen coordinates
            GeometryReader { geometry in
                let screenFrame = NSScreen.main?.frame ?? CGRect(origin: .zero, size: geometry.size)
                ForEach(localAvailableWindows, id: \.windowID) { window in
                    windowHighlight(for: window, screenFrame: screenFrame)
                }
            }

            // Bottom toolbar
            VStack {
                Spacer()
                bottomToolbar
            }
        }
        .onAppear {
            Task {
                await windowCaptureManager.refreshAvailableWindows()
                // Copy to local state
                localAvailableWindows = windowCaptureManager.availableWindows
                localSelectedWindows = windowCaptureManager.selectedWindows
            }
        }
        .onReceive(windowCaptureManager.$availableWindows) { windows in
            localAvailableWindows = windows
        }
        .onReceive(windowCaptureManager.$selectedWindows) { windows in
            localSelectedWindows = windows
        }
    }

    // MARK: - Window Highlight View

    @ViewBuilder
    private func windowHighlight(
        for window: AvailableWindow,
        screenFrame: CGRect
    ) -> some View {
        let frame = WindowSelectionOverlayHelpers.convertToOverlayFrame(
            window.frame,
            screenFrame: screenFrame
        )
        let isSelected = WindowSelectionOverlayHelpers.isSelected(
            windowID: window.windowID,
            in: localSelectedWindows
        )
        let isPrimary = WindowSelectionOverlayHelpers.isPrimary(
            windowID: window.windowID,
            in: localSelectedWindows
        )
        let isHovered = hoveredWindowID == window.windowID

        ZStack(alignment: .topLeading) {
            // Window border/highlight
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    borderColor(isSelected: isSelected, isPrimary: isPrimary, isHovered: isHovered),
                    lineWidth: isSelected ? 3 : (isHovered ? 2 : 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor(isSelected: isSelected, isHovered: isHovered))
                )

            // Window info overlay
            VStack(alignment: .leading, spacing: 2) {
                // App name and window title
                HStack(spacing: 4) {
                    Text(window.ownerName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)

                    if isPrimary {
                        Text("PRIMARY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .cornerRadius(3)
                    }
                }

                if !window.windowTitle.isEmpty {
                    Text(window.windowTitle)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
            .padding(4)
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .onHover { hovering in
            hoveredWindowID = hovering ? window.windowID : nil
        }
        .onTapGesture {
            handleWindowTap(window: window)
        }
        .simultaneousGesture(
            TapGesture()
                .modifiers(.command)
                .onEnded { _ in
                    handleCommandTap(window: window)
                }
        )
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 8) {
            // Selection count
            Text(WindowSelectionOverlayHelpers.selectionCountText(
                count: localSelectedWindows.count
            ))
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)

            // Warning for high window count
            if WindowSelectionOverlayHelpers.shouldShowWarning(
                selectedCount: localSelectedWindows.count,
                threshold: settings.windowCountWarningThreshold
            ) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(WindowSelectionOverlayHelpers.warningText(
                        count: localSelectedWindows.count
                    ))
                    .foregroundColor(.yellow)
                }
                .font(.system(size: 12))
            }

            // Instructions
            Text("Click to select \u{2022} \u{2318}+Click to set primary")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    // Clear local state first
                    localAvailableWindows = []
                    localSelectedWindows = []
                    windowCaptureManager.clearSelection()
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)

                Button("Done") {
                    // Clear local state first
                    localAvailableWindows = []
                    localSelectedWindows = []
                    onDismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .padding(.bottom, 40)
    }

    // MARK: - Helper Methods

    private func borderColor(isSelected: Bool, isPrimary: Bool, isHovered: Bool) -> Color {
        if isPrimary {
            return .blue
        } else if isSelected {
            return .green
        } else if isHovered {
            return .white.opacity(0.8)
        } else {
            return .white.opacity(0.4)
        }
    }

    private func backgroundColor(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return Color.white.opacity(0.1)
        } else if isHovered {
            return Color.white.opacity(0.05)
        } else {
            return Color.clear
        }
    }

    private func handleWindowTap(window: AvailableWindow) {
        let isCurrentlySelected = WindowSelectionOverlayHelpers.isSelected(
            windowID: window.windowID,
            in: localSelectedWindows
        )

        if isCurrentlySelected {
            // Clicking a selected window deselects it
            windowCaptureManager.deselectWindow(window.windowID)
        } else {
            // First selection becomes primary, subsequent ones are secondary
            let isPrimary = localSelectedWindows.isEmpty
            windowCaptureManager.selectWindow(window, asPrimary: isPrimary)
        }
    }

    private func handleCommandTap(window: AvailableWindow) {
        let isCurrentlySelected = WindowSelectionOverlayHelpers.isSelected(
            windowID: window.windowID,
            in: localSelectedWindows
        )

        if isCurrentlySelected {
            // Cmd+click on selected window sets it as primary
            windowCaptureManager.setPrimaryWindow(window.windowID)
        } else {
            // Cmd+click on unselected window selects it as primary
            windowCaptureManager.selectWindow(window, asPrimary: true)
        }
    }
}

// MARK: - Preview

#Preview {
    let settings = AppSettings()
    let windowCaptureManager = WindowCaptureManager(settings: settings)

    WindowSelectionOverlay(
        windowCaptureManager: windowCaptureManager,
        settings: settings,
        onDismiss: { }
    )
}
