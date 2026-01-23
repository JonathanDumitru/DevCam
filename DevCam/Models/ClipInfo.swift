import Foundation

struct ClipInfo: Identifiable, Codable {
    let id: UUID
    let fileURL: URL
    let timestamp: Date
    let duration: TimeInterval
    let fileSize: Int64 // bytes

    var fileSizeFormatted: String {
        let mb = Double(fileSize) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
