//
//  PreviewWindow.swift
//  DevCam
//
//  Preview window with video player and trim controls for clip export.
//

import SwiftUI
import AVKit
import AVFoundation
import CoreMedia

struct PreviewWindow: View {
    let videoURL: URL
    let onExport: (CMTimeRange) -> Void  // Called with selected range
    let onCancel: () -> Void

    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var duration: Double = 0
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            // Video Player
            videoPlayerSection

            Divider()

            // Trim Controls
            trimControlsSection

            Divider()

            // Selection Info and Actions
            actionSection
        }
        .frame(width: 640, height: 500)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: - Video Player Section

    private var videoPlayerSection: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 360)
            } else {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 360)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
    }

    // MARK: - Trim Controls Section

    private var trimControlsSection: some View {
        VStack(spacing: 8) {
            TrimSliderView(
                startTime: $startTime,
                endTime: $endTime,
                duration: duration,
                onSeek: { time in
                    seekToTime(time)
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: 16) {
            // Selection Info
            selectionInfoView

            // Action Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export Clip") {
                    exportClip()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var selectionInfoView: some View {
        HStack {
            Text("Selected: \(formatTime(startTime)) - \(formatTime(endTime)) (\(formatTime(selectedDuration)))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        Task {
            do {
                let durationValue = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(durationValue)

                await MainActor.run {
                    self.duration = durationSeconds
                    self.endTime = durationSeconds
                    self.player = AVPlayer(url: videoURL)
                }
            } catch {
                print("Failed to load video duration: \(error)")
                await MainActor.run {
                    self.player = AVPlayer(url: videoURL)
                }
            }
        }
    }

    private func seekToTime(_ time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Export

    private func exportClip() {
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
        onExport(timeRange)
    }

    // MARK: - Computed Properties

    private var selectedDuration: Double {
        return max(0, endTime - startTime)
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Window Presentation

    static func show(videoURL: URL, onExport: @escaping (CMTimeRange) -> Void) {
        let contentView = PreviewWindow(
            videoURL: videoURL,
            onExport: { timeRange in
                onExport(timeRange)
                if let window = NSApp.keyWindow {
                    window.close()
                }
            },
            onCancel: {
                if let window = NSApp.keyWindow {
                    window.close()
                }
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 640, height: 500)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preview"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Preview

#Preview {
    // Create a placeholder preview since we don't have a real video URL
    PreviewWindow(
        videoURL: URL(fileURLWithPath: "/tmp/sample.mov"),
        onExport: { timeRange in
            print("Export requested: \(timeRange)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
