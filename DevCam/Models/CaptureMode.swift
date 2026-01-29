//
//  CaptureMode.swift
//  DevCam
//
//  Capture mode selection and window selection models.
//

import Foundation
import CoreGraphics

/// Capture mode for recording
enum CaptureMode: String, Codable, Equatable {
    case display
    case windows

    var displayName: String {
        switch self {
        case .display: return "Display"
        case .windows: return "Windows"
        }
    }
}

/// Represents a selected window for capture
struct WindowSelection: Codable, Identifiable, Equatable {
    let windowID: CGWindowID
    let ownerName: String
    let windowTitle: String
    var isPrimary: Bool

    var id: CGWindowID { windowID }

    var displayName: String {
        if windowTitle.isEmpty {
            return ownerName
        }
        return "\(ownerName) - \(windowTitle)"
    }
}
