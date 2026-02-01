//
//  TrimSliderView.swift
//  DevCam
//
//  Dual-handle range slider for video trim selection
//

import SwiftUI

struct TrimSliderView: View {
    @Binding var startTime: Double  // Start of selection in seconds
    @Binding var endTime: Double    // End of selection in seconds
    let duration: Double            // Total clip duration in seconds
    var onSeek: ((Double) -> Void)? // Called when user drags handle

    // Minimum selection duration (1 second)
    private let minimumDuration: Double = 1.0

    // Handle sizing
    private let handleWidth: CGFloat = 12
    private let handleHeight: CGFloat = 24
    private let trackHeight: CGFloat = 8

    var body: some View {
        VStack(spacing: 8) {
            // Slider track with handles
            GeometryReader { geometry in
                let trackWidth = geometry.size.width - handleWidth

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: trackHeight)

                    // Selected region
                    selectedRegion(trackWidth: trackWidth)

                    // Start handle
                    startHandle(trackWidth: trackWidth)

                    // End handle
                    endHandle(trackWidth: trackWidth)
                }
                .frame(height: handleHeight)
            }
            .frame(height: handleHeight)

            // Time labels
            HStack {
                Text(formatTime(startTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatTime(endTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Slider Components

    private func selectedRegion(trackWidth: CGFloat) -> some View {
        let startPosition = positionForTime(startTime, trackWidth: trackWidth)
        let endPosition = positionForTime(endTime, trackWidth: trackWidth)
        let selectionWidth = endPosition - startPosition + handleWidth

        return RoundedRectangle(cornerRadius: trackHeight / 2)
            .fill(Color.accentColor.opacity(0.5))
            .frame(width: max(0, selectionWidth), height: trackHeight)
            .offset(x: startPosition)
    }

    private func startHandle(trackWidth: CGFloat) -> some View {
        let position = positionForTime(startTime, trackWidth: trackWidth)

        return handleView()
            .offset(x: position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPosition = value.location.x - handleWidth / 2
                        let newTime = timeForPosition(newPosition, trackWidth: trackWidth)

                        // Clamp to valid range: 0 to (endTime - minimumDuration)
                        let clampedTime = max(0, min(newTime, endTime - minimumDuration))
                        startTime = clampedTime
                        onSeek?(clampedTime)
                    }
            )
    }

    private func endHandle(trackWidth: CGFloat) -> some View {
        let position = positionForTime(endTime, trackWidth: trackWidth)

        return handleView()
            .offset(x: position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPosition = value.location.x - handleWidth / 2
                        let newTime = timeForPosition(newPosition, trackWidth: trackWidth)

                        // Clamp to valid range: (startTime + minimumDuration) to duration
                        let clampedTime = max(startTime + minimumDuration, min(newTime, duration))
                        endTime = clampedTime
                        onSeek?(clampedTime)
                    }
            )
    }

    private func handleView() -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor)
            .frame(width: handleWidth, height: handleHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
    }

    // MARK: - Position Calculations

    private func positionForTime(_ time: Double, trackWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let percentage = time / duration
        return CGFloat(percentage) * trackWidth
    }

    private func timeForPosition(_ position: CGFloat, trackWidth: CGFloat) -> Double {
        guard trackWidth > 0 else { return 0 }
        let percentage = Double(position / trackWidth)
        return percentage * duration
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var startTime: Double = 10
        @State private var endTime: Double = 45

        var body: some View {
            VStack(spacing: 20) {
                TrimSliderView(
                    startTime: $startTime,
                    endTime: $endTime,
                    duration: 60,
                    onSeek: { time in
                        print("Seeking to: \(time)")
                    }
                )

                Text("Selection: \(String(format: "%.1f", startTime))s - \(String(format: "%.1f", endTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
