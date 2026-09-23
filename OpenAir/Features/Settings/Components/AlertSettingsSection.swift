import SwiftUI
import UIKit

struct AlertSettingsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var showsPermissionAlert = false

    var body: some View {
        Section {
            Toggle("Open and close alerts", isOn: alertsEnabled)
                .disabled(store.isRequestingNotificationPermission)
        } header: {
            Text("Alerts")
        } footer: {
            Text("Alerts use the latest downloaded forecast. iOS may delay or skip background refreshes.")
        }
        .task { await store.refreshNotificationPermission() }
        .alert("Notifications are disabled", isPresented: $showsPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    store.enableAlertsWhenPermissionGranted()
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for OpenAir in Settings to receive open and close alerts.")
        }
    }

    private var alertsEnabled: Binding<Bool> {
        Binding {
            store.alertsEffectivelyEnabled
        } set: { isEnabled in
            Task {
                let enabled = await store.setAlertsEnabled(isEnabled)
                if isEnabled && !enabled && store.notificationStatus == .denied {
                    showsPermissionAlert = true
                }
            }
        }
    }

}
