import Foundation

struct ClipInfo: Identifiable, Codable {
    let id: UUID
    let fileURL: URL
    let timestamp: Date
    let duration: TimeInterval
    let fileSize: Int64 // bytes

    // Annotation fields (Phase 3)
    var title: String?
    var notes: String?
    var tags: [String]

    init(id: UUID, fileURL: URL, timestamp: Date, duration: TimeInterval, fileSize: Int64, title: String? = nil, notes: String? = nil, tags: [String] = []) {
        self.id = id
        self.fileURL = fileURL
        self.timestamp = timestamp
        self.duration = duration
        self.fileSize = fileSize
        self.title = title
        self.notes = notes
        self.tags = tags
    }

    var fileSizeFormatted: String {
        let mb = Double(fileSize) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return "Clip \(timestamp.formatted(date: .abbreviated, time: .shortened))"
    }

    var hasAnnotations: Bool {
        (title != nil && !title!.isEmpty) || (notes != nil && !notes!.isEmpty) || !tags.isEmpty
    }
}
