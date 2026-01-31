//
//  DisplaySwitchConfirmationView.swift
//  DevCam
//
//  Confirmation dialog for switching display during recording.
//  Warns user that buffer will be cleared when switching displays.
//

import SwiftUI

struct DisplaySwitchConfirmationView: View {
    let targetDisplayName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "display.2")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            Text("Switch Display?")
                .font(.headline)

            Text("Switching to \(targetDisplayName) will clear your current buffer. Any unsaved footage will be lost.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Button("Switch Display") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

// MARK: - Preview

#Preview {
    DisplaySwitchConfirmationView(
        targetDisplayName: "Display 2 (1920×1080)",
        onConfirm: { print("Confirmed") },
        onCancel: { print("Cancelled") }
    )
}
