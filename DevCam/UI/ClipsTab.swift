//
//  ClipsTab.swift
//  DevCam
//
//  Recent clips browser with annotations display and actions
//

import SwiftUI

struct ClipsTab: View {
    @ObservedObject var clipExporter: ClipExporter
    @State private var selectedClip: ClipInfo?
    @State private var filterTag: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Clips")
                    .font(.headline)

                Spacer()

                // Tag filter (if any clips have tags)
                if hasAnyTags {
                    tagFilterMenu
                }

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
            if filteredClips.isEmpty {
                if filterTag != nil {
                    noFilterResultsState
                } else {
                    emptyState
                }
            } else {
                clipsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $selectedClip) { clip in
            ClipDetailView(clip: clip, clipExporter: clipExporter)
        }
    }

    // MARK: - Computed Properties

    private var hasAnyTags: Bool {
        clipExporter.recentClips.contains { !$0.tags.isEmpty }
    }

    private var allTags: [String] {
        let tags = clipExporter.recentClips.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }

    private var filteredClips: [ClipInfo] {
        guard let tag = filterTag else {
            return clipExporter.recentClips
        }
        return clipExporter.recentClips.filter { $0.tags.contains(tag) }
    }

    // MARK: - Tag Filter Menu

    private var tagFilterMenu: some View {
        Menu {
            Button("All Clips") {
                filterTag = nil
            }

            Divider()

            ForEach(allTags, id: \.self) { tag in
                Button(tag) {
                    filterTag = tag
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                Text(filterTag ?? "Filter")
            }
            .font(.system(size: 12))
        }
        .menuStyle(.borderlessButton)
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

    private var noFilterResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No clips with tag \"\(filterTag ?? "")\"")
                .font(.headline)
                .foregroundColor(.secondary)

            Button("Clear Filter") {
                filterTag = nil
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Clips List

    private var clipsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredClips) { clip in
                    clipRow(clip)
                }
            }
            .padding()
        }
    }

    private func clipRow(_ clip: ClipInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Thumbnail placeholder with annotation indicator
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)

                    // Annotation indicator
                    if clip.hasAnnotations {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    // Title or filename
                    Text(clip.displayTitle)
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
                    // View details button (for clips with annotations)
                    if clip.hasAnnotations {
                        Button {
                            selectedClip = clip
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("View details")
                    }

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

            // Tags row (if any)
            if !clip.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(clip.tags, id: \.self) { tag in
                            TagBadge(tag: tag) {
                                filterTag = tag
                            }
                        }
                    }
                }
            }

            // Notes preview (if any)
            if let notes = clip.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(clip.fileURL)
        }
    }
}

// MARK: - Tag Badge

struct TagBadge: View {
    let tag: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 2) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 8))
                Text(tag)
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clip Detail View

struct ClipDetailView: View {
    let clip: ClipInfo
    let clipExporter: ClipExporter
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Clip Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }

            Divider()

            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(clip.displayTitle)
                    .font(.headline)
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text("File")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(clip.fileURL.lastPathComponent)
                    .font(.system(size: 13, design: .monospaced))
            }

            // Duration & Size
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(clip.durationFormatted)
                        .font(.system(size: 14, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(clip.fileSizeFormatted)
                        .font(.system(size: 14, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(clip.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14))
                }
            }

            // Tags
            if !clip.tags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 4) {
                        ForEach(clip.tags, id: \.self) { tag in
                            TagBadge(tag: tag) { }
                        }
                    }
                }
            }

            // Notes
            if let notes = clip.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(notes)
                        .font(.system(size: 13))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                }
            }

            Spacer()

            // Actions
            HStack {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(clip.fileURL.path, inFileViewerRootedAtPath: "")
                }

                Spacer()

                Button("Play") {
                    NSWorkspace.shared.open(clip.fileURL)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 450)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

// MARK: - Preview

#Preview {
    let bufferManager = BufferManager()
    let settings = AppSettings()
    let clipExporter = ClipExporter(
        bufferManager: bufferManager,
        settings: settings
    )

    return ClipsTab(clipExporter: clipExporter)
        .frame(width: 500, height: 400)
}
