import Foundation

struct SegmentInfo: Identifiable, Codable, Equatable {
    let id: UUID
    let fileURL: URL
    let startTime: Date
    let duration: TimeInterval

    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }
}
