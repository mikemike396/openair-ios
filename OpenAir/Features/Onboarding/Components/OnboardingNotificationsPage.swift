import SwiftUI
import UIKit
import UserNotifications

struct OnboardingNotificationsPage: View {
    @Environment(\.openURL) private var openURL
    let authorizationStatus: UNAuthorizationStatus
    let statusLabel: String
    let requestPermission: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(.openAirTeal)

            Text("Best-effort alerts")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("OpenAir can schedule the next forecasted open and close times. iOS may delay background updates, so alerts can become stale.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if authorizationStatus == .denied {
                Button("Open Settings", systemImage: "gearshape") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.glassProminent)
            } else if authorizationStatus == .notDetermined {
                Button("Allow Notifications", systemImage: "bell.fill", action: requestPermission)
                    .buttonStyle(.glassProminent)
            }

            Text(statusLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
