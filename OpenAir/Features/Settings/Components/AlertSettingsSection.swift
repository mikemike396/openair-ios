import SwiftUI
import UIKit

struct AlertSettingsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section("Alerts") {
            Toggle("Open and close alerts", isOn: alertsEnabled)
                .disabled(store.isRequestingNotificationPermission)
            LabeledContent("Permission", value: notificationLabel)
            if store.preferences.alertsEnabled {
                if store.notificationStatus == .notDetermined {
                    Button("Allow Notifications") {
                        Task { await store.requestNotificationPermission() }
                    }
                    .disabled(store.isRequestingNotificationPermission)
                } else if store.notificationStatus == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
            Text("Alerts use the latest downloaded forecast. iOS may delay or skip background refreshes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .task { await store.refreshNotificationPermission() }
    }

    private var alertsEnabled: Binding<Bool> {
        Binding {
            store.preferences.alertsEnabled
        } set: { isEnabled in
            Task { await store.setAlertsEnabled(isEnabled) }
        }
    }

    private var notificationLabel: String {
        switch store.notificationStatus {
        case .authorized, .provisional, .ephemeral: "Allowed"
        case .denied: "Denied"
        default: "Not requested"
        }
    }
}
