import SwiftUI

struct OnboardingNotificationsPage: View {
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

            Button("Allow Notifications", systemImage: "bell.fill", action: requestPermission)
                .buttonStyle(.glassProminent)

            Text(statusLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
