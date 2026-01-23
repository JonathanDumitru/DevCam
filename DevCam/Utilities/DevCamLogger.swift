import OSLog

enum DevCamLogger {
    static let subsystem = "Jonathan-Hines-Dumitru.DevCam"
    static let app = Logger(subsystem: subsystem, category: "App")
    static let recording = Logger(subsystem: subsystem, category: "Recording")
    static let export = Logger(subsystem: subsystem, category: "Export")
    static let permissions = Logger(subsystem: subsystem, category: "Permissions")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
}
