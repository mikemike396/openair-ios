import SwiftUI
import UIKit

struct AlertSettingsSection: View {
    @Environment(NotificationStore.self) private var notifications
    @Environment(\.openURL) private var openURL
    @State private var showsPermissionAlert = false

    var body: some View {
        Section {
            Toggle("Open and close alerts", isOn: alertsEnabled)
                .disabled(notifications.isRequestingPermission)
        } header: {
            Text("Alerts")
        } footer: {
            Text("Alerts use the latest downloaded forecast. iOS may delay or skip background refreshes.")
        }
        .task { await notifications.refreshPermission() }
        .alert("Notifications are disabled", isPresented: $showsPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    notifications.enableAlertsWhenPermissionGranted()
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
            notifications.alertsEffectivelyEnabled
        } set: { isEnabled in
            Task {
                let enabled = await notifications.setAlertsEnabled(isEnabled)
                if isEnabled && !enabled && notifications.authorizationStatus == .denied {
                    showsPermissionAlert = true
                }
            }
        }
    }

}
