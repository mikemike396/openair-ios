import Foundation
import Observation
import UserNotifications

@Observable
final class NotificationStore {
    private let scheduler: any NotificationScheduling
    private let preferences: any UserPreferenceStoring
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var isRequestingPermission = false
    @ObservationIgnored var onAuthorizationChanged: (() async -> Void)?
    @ObservationIgnored var onPreferencesChanged: ((ComfortPreferences) -> Void)?

    var notificationsAllowed: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }
    var alertsEffectivelyEnabled: Bool { preferences.preferences.alertsEnabled && notificationsAllowed }

    init(scheduler: any NotificationScheduling, preferences: any UserPreferenceStoring) {
        self.scheduler = scheduler
        self.preferences = preferences
    }

    func refreshPermission() async {
        let previous = authorizationStatus
        authorizationStatus = await scheduler.authorizationStatus()
        if authorizationStatus != previous { await onAuthorizationChanged?() }
    }

    func requestPermission() async {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        await refreshPermission()
        if authorizationStatus == .notDetermined { _ = try? await scheduler.requestAuthorization() }
        await refreshPermission()
    }

    /// Preserve the user's Settings handoff without displaying the switch as on before access is granted.
    func enableAlertsWhenPermissionGranted() {
        var updated = preferences.preferences
        updated.alertsEnabled = true
        updatePreferences(updated.normalized)
    }

    @discardableResult
    func setAlertsEnabled(_ enabled: Bool) async -> Bool {
        if enabled { await requestPermission() }
        var updated = preferences.preferences
        updated.alertsEnabled = enabled && notificationsAllowed
        updatePreferences(updated.normalized)
        return updated.alertsEnabled
    }

    func synchronize(plan: RecommendationPlan, locationName: String) async {
        await scheduler.replaceNotifications(plan: plan, locationName: locationName, enabled: preferences.preferences.alertsEnabled)
    }

    func notifyCurrentChange(status: RecommendationStatus, locationName: String) async {
        guard preferences.preferences.alertsEnabled else { return }
        await scheduler.notifyCurrentChange(status: status, locationName: locationName)
    }

    private func updatePreferences(_ updated: ComfortPreferences) {
        if let onPreferencesChanged { onPreferencesChanged(updated) }
        else { preferences.preferences = updated }
    }
}
