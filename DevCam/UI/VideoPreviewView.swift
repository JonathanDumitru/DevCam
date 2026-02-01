//
//  VideoPreviewView.swift
//  DevCam
//
//  Video preview player for clip export preview
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoPreviewView: View {
    let segments: [SegmentInfo]
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let timeObserverInterval = CMTime(seconds: 0.1, preferredTimescale: 600)

    var body: some View {
        VStack(spacing: 8) {
            // Video player area
            ZStack {
                if let error = errorMessage {
                    errorView(error)
                } else if isLoading {
                    loadingView
                } else if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                } else {
                    noPreviewView
                }
            }
            .frame(height: 180)

            // Playback controls
            if player != nil && errorMessage == nil {
                playbackControls
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: segments) { _ in
            setupPlayer()
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading preview...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var noPreviewView: some View {
        VStack(spacing: 8) {
            Image(systemName: "film.slash")
                .font(.title)
                .foregroundColor(.secondary)
            Text("No preview available")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var playbackControls: some View {
        VStack(spacing: 6) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 4)
                        .cornerRadius(2)

                    // Progress
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (duration > 0 ? currentTime / duration : 0), height: 4)
                        .cornerRadius(2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percentage = max(0, min(1, value.location.x / geometry.size.width))
                            let seekTime = percentage * duration
                            player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                        }
                )
            }
            .frame(height: 4)

            // Controls row
            HStack {
                // Current time
                Text(formatTime(currentTime))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)

                Spacer()

                // Play/Pause button
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.body)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.space, modifiers: [])
                .help(isPlaying ? "Pause" : "Play")

                // Restart button
                Button(action: restart) {
                    Image(systemName: "backward.end.fill")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .help("Restart")

                Spacer()

                // Duration
                Text(formatTime(duration))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        cleanupPlayer()

        guard !segments.isEmpty else {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Create a composition from the segments
                let composition = try await createComposition(from: segments)

                let playerItem = AVPlayerItem(asset: composition)
                let newPlayer = AVPlayer(playerItem: playerItem)

                // Observe time updates
                newPlayer.addPeriodicTimeObserver(forInterval: timeObserverInterval, queue: .main) { time in
                    currentTime = time.seconds
                }

                // Get duration
                let assetDuration = try await composition.load(.duration)

                await MainActor.run {
                    self.player = newPlayer
                    self.duration = assetDuration.seconds
                    self.isLoading = false
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not load preview"
                    self.isLoading = false
                }
            }
        }
    }

    private func createComposition(from segments: [SegmentInfo]) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw PreviewError.compositionFailed
        }

        var currentTime = CMTime.zero

        for segment in segments {
            let asset = AVURLAsset(url: segment.fileURL)

            // Load tracks asynchronously
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let assetVideoTrack = tracks.first else {
                continue
            }

            let assetDuration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: assetDuration)

            try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, assetDuration)
        }

        return composition
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    // MARK: - Playback Controls

    private func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            // If at end, restart
            if currentTime >= duration - 0.1 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    private func restart() {
        player?.seek(to: .zero)
        currentTime = 0
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview Error

enum PreviewError: Error {
    case compositionFailed
    case noVideoTrack
}

// MARK: - Preview

#Preview {
    VideoPreviewView(segments: [])
        .frame(width: 400, height: 250)
        .padding()
}
