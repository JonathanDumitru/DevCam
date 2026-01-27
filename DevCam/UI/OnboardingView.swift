//
//  OnboardingView.swift
//  DevCam
//
//  First-launch onboarding flow explaining permissions and app functionality.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissionManager: PermissionManager
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)

                HowItWorksPage()
                    .tag(1)

                PermissionPage(permissionManager: permissionManager)
                    .tag(2)

                ReadyPage()
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack {
                // Back button
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 60)
                }

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                // Next/Finish button
                if currentPage < 3 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        markOnboardingComplete()
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!permissionManager.hasScreenRecordingPermission)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
    }

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "HasCompletedOnboarding")
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "record.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("Welcome to DevCam")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Never lose that perfect bug reproduction or demo again")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

// MARK: - How It Works Page

struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("How It Works")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "record.circle",
                    title: "Continuous Recording",
                    description: "DevCam quietly records your screen in the background, keeping the last 15 minutes in a rolling buffer."
                )

                FeatureRow(
                    icon: "clock.arrow.circlepath",
                    title: "Retroactive Saving",
                    description: "Something interesting happened? Save a clip of the last 5, 10, or 15 minutes with a single click."
                )

                FeatureRow(
                    icon: "bolt.fill",
                    title: "Always Ready",
                    description: "No need to remember to start recording. DevCam is always capturing, so you never miss a moment."
                )

                FeatureRow(
                    icon: "lock.shield",
                    title: "100% Local",
                    description: "Your recordings never leave your Mac. No cloud, no accounts, complete privacy."
                )
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Permission Page

struct PermissionPage: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 24) {
            Text("Screen Recording Permission")
                .font(.title)
                .fontWeight(.bold)

            Image(systemName: permissionManager.hasScreenRecordingPermission ? "checkmark.shield.fill" : "shield.fill")
                .font(.system(size: 48))
                .foregroundColor(permissionManager.hasScreenRecordingPermission ? .green : .orange)

            if permissionManager.hasScreenRecordingPermission {
                Text("Permission Granted!")
                    .font(.title2)
                    .foregroundColor(.green)

                Text("DevCam can now record your screen. You're all set!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("DevCam needs permission to record your screen.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    PermissionStep(number: 1, text: "Click \"Request Permission\" below")
                    PermissionStep(number: 2, text: "System Settings will open")
                    PermissionStep(number: 3, text: "Enable \"DevCam\" in the list")
                    PermissionStep(number: 4, text: "Return here to continue")
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                HStack(spacing: 16) {
                    Button("Request Permission") {
                        permissionManager.requestScreenRecordingPermission()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open System Settings") {
                        permissionManager.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Check Again") {
                    permissionManager.checkPermission()
                }
                .buttonStyle(.plain)
                .font(.caption)
            }

            Spacer()
        }
        .padding()
    }
}

struct PermissionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Ready Page

struct ReadyPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                Text("DevCam will start recording automatically when you click \"Get Started\".")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    TipRow(icon: "menubar.rectangle", text: "Click the menubar icon to save clips")
                    TipRow(icon: "keyboard", text: "Use ⌘⌥5/6/7 for quick saves")
                    TipRow(icon: "gearshape", text: "Open Preferences to customize settings")
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView(
        permissionManager: PermissionManager(),
        onComplete: { }
    )
}

#Preview("Welcome Page") {
    WelcomePage()
        .frame(width: 500, height: 350)
}

#Preview("How It Works") {
    HowItWorksPage()
        .frame(width: 500, height: 350)
}

#Preview("Permission Page") {
    PermissionPage(permissionManager: PermissionManager())
        .frame(width: 500, height: 350)
}

#Preview("Ready Page") {
    ReadyPage()
        .frame(width: 500, height: 350)
}
