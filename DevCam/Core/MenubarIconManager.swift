//
//  MenubarIconManager.swift
//  DevCam
//
//  Manages dynamic menubar icon rendering with state indicators and buffer badge.
//

import Foundation
import AppKit
import Combine
import OSLog

@MainActor
class MenubarIconManager: ObservableObject {

    // MARK: - State

    enum IconState {
        case recording
        case recordingDegraded
        case paused
        case error
        case recovering
        case exporting(progress: Double)

        var symbolName: String {
            switch self {
            case .recording, .recordingDegraded:
                return "record.circle.fill"
            case .paused:
                return "pause.circle"
            case .error:
                return "exclamationmark.circle.fill"
            case .recovering:
                return "arrow.clockwise.circle"
            case .exporting:
                return "square.and.arrow.up.circle"
            }
        }

        var tintColor: NSColor {
            switch self {
            case .recording:
                return .systemRed
            case .recordingDegraded:
                return .systemYellow
            case .paused:
                return .systemGray
            case .error:
                return .systemOrange
            case .recovering:
                return .systemYellow
            case .exporting:
                return .systemBlue
            }
        }

        var tooltip: String {
            switch self {
            case .recording:
                return "DevCam: Recording"
            case .recordingDegraded:
                return "DevCam: Recording (Reduced Quality)"
            case .paused:
                return "DevCam: Paused"
            case .error:
                return "DevCam: Error - Click for details"
            case .recovering:
                return "DevCam: Recovering..."
            case .exporting(let progress):
                return "DevCam: Exporting (\(Int(progress * 100))%)"
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var currentState: IconState = .paused
    @Published private(set) var bufferMinutes: Int = 0

    // MARK: - Dependencies

    private weak var statusButton: NSStatusBarButton?
    private var cancellables = Set<AnyCancellable>()
    private var pulseTimer: Timer?
    private var pulseOpacity: CGFloat = 1.0

    // MARK: - Configuration

    private let showBadge: Bool = true
    private let enablePulseAnimation: Bool = true

    // MARK: - Initialization

    init() {}

    func configure(
        statusButton: NSStatusBarButton,
        recordingManager: RecordingManager,
        clipExporter: ClipExporter
    ) {
        self.statusButton = statusButton

        // Observe recording state
        recordingManager.$isRecording
            .combineLatest(
                recordingManager.$recordingError,
                recordingManager.$isInRecoveryMode,
                recordingManager.$isQualityDegraded
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, error, isRecovering, isDegraded in
                self?.updateState(
                    isRecording: isRecording,
                    hasError: error != nil,
                    isRecovering: isRecovering,
                    isDegraded: isDegraded
                )
            }
            .store(in: &cancellables)

        // Observe buffer duration
        recordingManager.$bufferDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.bufferMinutes = Int(duration / 60)
                self?.renderIcon()
            }
            .store(in: &cancellables)

        // Observe export progress
        clipExporter.$isExporting
            .combineLatest(clipExporter.$exportProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isExporting, progress in
                if isExporting {
                    self?.currentState = .exporting(progress: progress)
                    self?.renderIcon()
                }
            }
            .store(in: &cancellables)

        // Initial render
        renderIcon()
    }

    // MARK: - State Updates

    private func updateState(isRecording: Bool, hasError: Bool, isRecovering: Bool, isDegraded: Bool) {
        let newState: IconState

        if isRecovering {
            newState = .recovering
        } else if hasError {
            newState = .error
        } else if isRecording {
            newState = isDegraded ? .recordingDegraded : .recording
        } else {
            newState = .paused
        }

        currentState = newState
        updatePulseAnimation()
        renderIcon()
    }

    // MARK: - Rendering

    private func renderIcon() {
        guard let button = statusButton else { return }

        let iconSize = NSSize(width: 22, height: 22)
        let image = NSImage(size: iconSize, flipped: false) { rect in
            self.drawIcon(in: rect)
            return true
        }

        image.isTemplate = false
        button.image = image
        button.toolTip = currentState.tooltip
    }

    private func drawIcon(in rect: NSRect) {
        // Draw base icon
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard var symbolImage = NSImage(systemSymbolName: currentState.symbolName, accessibilityDescription: nil) else {
            return
        }

        symbolImage = symbolImage.withSymbolConfiguration(symbolConfig) ?? symbolImage

        // Apply tint and opacity for pulse animation
        let tintedImage = symbolImage.tinted(with: currentState.tintColor.withAlphaComponent(pulseOpacity))

        // Center the symbol
        let symbolRect = NSRect(
            x: (rect.width - 16) / 2,
            y: (rect.height - 16) / 2 + 1,
            width: 16,
            height: 16
        )
        tintedImage.draw(in: symbolRect)

        // Draw badge if enabled and recording
        if showBadge && bufferMinutes > 0 {
            drawBadge(in: rect, minutes: bufferMinutes)
        }
    }

    private func drawBadge(in rect: NSRect, minutes: Int) {
        let badgeText = "\(minutes)"
        let font = NSFont.systemFont(ofSize: 8, weight: .bold)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let textSize = (badgeText as NSString).size(withAttributes: attributes)
        let badgeWidth = max(textSize.width + 4, 10)
        let badgeHeight: CGFloat = 10

        // Position badge at bottom-right
        let badgeRect = NSRect(
            x: rect.width - badgeWidth - 1,
            y: 1,
            width: badgeWidth,
            height: badgeHeight
        )

        // Draw badge background
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3)
        NSColor.systemBlue.setFill()
        badgePath.fill()

        // Draw text centered in badge
        let textRect = NSRect(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        (badgeText as NSString).draw(in: textRect, withAttributes: attributes)
    }

    // MARK: - Pulse Animation

    private func updatePulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil

        // Only pulse during active recording (not degraded, error, etc.)
        guard enablePulseAnimation, case .recording = currentState else {
            pulseOpacity = 1.0
            return
        }

        // Check for reduced motion preference
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            pulseOpacity = 1.0
            return
        }

        // Start pulse animation
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Sine wave for smooth pulsing: 0.7 to 1.0 over 2 seconds
            let time = Date().timeIntervalSince1970
            let phase = (time.truncatingRemainder(dividingBy: 2.0)) / 2.0
            self.pulseOpacity = 0.7 + 0.3 * CGFloat(sin(phase * .pi * 2))

            Task { @MainActor in
                self.renderIcon()
            }
        }
    }

    // MARK: - Cleanup

    func stopAnimations() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}

// MARK: - NSImage Extension

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
