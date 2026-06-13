import SwiftUI

struct AlertSettingsSection: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Section("Alerts") {
            Toggle("Open and close alerts", isOn: alertsEnabled)
            LabeledContent("Permission", value: notificationLabel)
            Text("Alerts use the latest downloaded forecast. iOS may delay or skip background refreshes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var alertsEnabled: Binding<Bool> {
        Binding {
            store.preferences.alertsEnabled
        } set: { isEnabled in
            var preferences = store.preferences
            preferences.alertsEnabled = isEnabled
            store.preferences = preferences.normalized
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
