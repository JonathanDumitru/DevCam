//
//  ClipsTab.swift
//  DevCam
//
//  Recent clips browser with actions
//

import SwiftUI

struct ClipsTab: View {
    @ObservedObject var clipExporter: ClipExporter

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Clips")
                    .font(.headline)

                Spacer()

                if !clipExporter.recentClips.isEmpty {
                    Button("Clear All") {
                        clipExporter.clearRecentClips()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()

            Divider()

            // Clips list
            if clipExporter.recentClips.isEmpty {
                emptyState
            } else {
                clipsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No clips saved yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Use keyboard shortcuts or the menubar to save clips")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Clips List

    private var clipsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(clipExporter.recentClips) { clip in
                    clipRow(clip)
                }
            }
            .padding()
        }
    }

    private func clipRow(_ clip: ClipInfo) -> some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            Image(systemName: "film.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.fileURL.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(clip.durationFormatted, systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Label(clip.fileSizeFormatted, systemImage: "doc")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(clip.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.open(clip.fileURL)
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
                .help("Open clip")

                Button {
                    NSWorkspace.shared.selectFile(clip.fileURL.path, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")

                Button {
                    clipExporter.deleteClip(clip)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete clip")
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    let bufferManager = BufferManager()
    let clipExporter = ClipExporter(
        bufferManager: bufferManager,
        saveLocation: nil,
        showNotifications: false
    )

    return ClipsTab(clipExporter: clipExporter)
        .frame(width: 500, height: 400)
}
