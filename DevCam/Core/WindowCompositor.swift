//
//  WindowCompositor.swift
//  DevCam
//
//  Composites multiple window frames into a single PiP layout.
//

import Foundation
import CoreImage
import CoreGraphics
import Combine

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
