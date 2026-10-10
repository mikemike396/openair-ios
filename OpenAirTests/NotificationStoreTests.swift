import CoreLocation
import Testing
import UserNotifications
@testable import OpenAir

@Suite
struct NotificationStoreTests {
    @Test
    func standaloneStoreCoalescesConcurrentPermissionRequests() async {
        let scheduler = SuspendedNotificationScheduler()
        let store = NotificationStore(scheduler: scheduler, preferences: InMemoryUserPreferenceStore())
        let first = Task { await store.requestPermission() }
        await scheduler.waitUntilRequested()

        await store.requestPermission()

        #expect(scheduler.requestCount == 1)
        #expect(store.isRequestingPermission)
        scheduler.grantPermission()
        await first.value
        #expect(store.authorizationStatus == .authorized)
        #expect(!store.isRequestingPermission)
    }

    @Test
    func activationReadsPermissionEvenBeforeOnboarding() async {
        let fixture = TravelFixture()
        fixture.preferences.hasCompletedOnboarding = false
        #expect(await fixture.store.coordinator.refreshOnActivation() == .skipped)
        #expect(fixture.store.notificationStore.authorizationStatus == .authorized)
        #expect(fixture.notifications.requestCount == 0)
        fixture.notifications.status = .denied
        await fixture.store.coordinator.refreshOnActivation()
        #expect(fixture.store.notificationStore.authorizationStatus == .denied)
    }

    @Test
    func enablingAlertsRequestsPermissionAndSchedulesLoadedForecast() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .notDetermined
        await fixture.store.weatherStore.usePreviewWeather()
        await fixture.store.notificationStore.setAlertsEnabled(true)
        #expect(fixture.store.userPreferences.preferences.alertsEnabled)
        #expect(fixture.notifications.requestCount == 1)
        #expect(fixture.store.notificationStore.authorizationStatus == .authorized)
        #expect(!fixture.store.notificationStore.isRequestingPermission)
        #expect(!fixture.notifications.names.isEmpty)
    }

    @Test(arguments: [UNAuthorizationStatus.authorized, .denied, .provisional])
    func existingPermissionDoesNotPromptAgain(status: UNAuthorizationStatus) async {
        let fixture = TravelFixture()
        fixture.notifications.status = status
        await fixture.store.notificationStore.setAlertsEnabled(true)
        #expect(fixture.notifications.requestCount == 0)
        #expect(fixture.store.notificationStore.authorizationStatus == status)
        #expect(fixture.store.notificationStore.alertsEffectivelyEnabled == (status != .denied))
        #expect(fixture.store.userPreferences.preferences.alertsEnabled == (status != .denied))
    }

    @Test
    func deniedRequestLeavesAlertsOff() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .notDetermined
        fixture.notifications.requestedStatus = .denied
        #expect(await fixture.store.notificationStore.setAlertsEnabled(true) == false)
        #expect(!fixture.store.userPreferences.preferences.alertsEnabled)
        #expect(!fixture.store.notificationStore.alertsEffectivelyEnabled)
    }

    @Test
    func grantingPermissionInSettingsCompletesPendingEnable() async {
        let fixture = TravelFixture()
        fixture.preferences.hasCompletedOnboarding = false
        fixture.notifications.status = .denied
        await fixture.store.notificationStore.setAlertsEnabled(true)
        #expect(!fixture.store.notificationStore.alertsEffectivelyEnabled)
        fixture.store.notificationStore.enableAlertsWhenPermissionGranted()
        #expect(fixture.store.userPreferences.preferences.alertsEnabled)
        #expect(!fixture.store.notificationStore.alertsEffectivelyEnabled)
        await fixture.store.coordinator.refreshOnActivation()
        #expect(!fixture.store.notificationStore.alertsEffectivelyEnabled)
        fixture.notifications.status = .authorized
        await fixture.store.coordinator.refreshOnActivation()
        #expect(fixture.store.notificationStore.alertsEffectivelyEnabled)
        #expect(fixture.notifications.requestCount == 0)
    }

    @Test
    func cancellingPermissionAlertDoesNotEnableAfterExternalPermissionChange() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .denied
        await fixture.store.notificationStore.setAlertsEnabled(true)
        // Cancel does not save a pending enable request.
        fixture.notifications.status = .authorized
        await fixture.store.notificationStore.refreshPermission()
        #expect(!fixture.store.notificationStore.alertsEffectivelyEnabled)
        #expect(!fixture.store.userPreferences.preferences.alertsEnabled)
    }

    @Test
    func revokingPermissionTurnsEffectiveSwitchOff() async {
        let fixture = TravelFixture()
        await fixture.store.notificationStore.setAlertsEnabled(true)
        #expect(fixture.store.notificationStore.alertsEffectivelyEnabled)
        fixture.notifications.status = .denied
        await fixture.store.notificationStore.refreshPermission()
        #expect(!fixture.store.notificationStore.alertsEffectivelyEnabled)
        fixture.notifications.status = .authorized
        await fixture.store.notificationStore.refreshPermission()
        #expect(fixture.store.notificationStore.alertsEffectivelyEnabled)
        await fixture.store.notificationStore.setAlertsEnabled(false)
        #expect(!fixture.store.notificationStore.alertsEffectivelyEnabled)
    }

    @Test
    func disablingAlertsDoesNotRequestPermission() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .notDetermined
        await fixture.store.notificationStore.setAlertsEnabled(false)
        #expect(!fixture.store.userPreferences.preferences.alertsEnabled)
        #expect(fixture.notifications.requestCount == 0)
    }

    @Test
    func declinedRequestUpdatesLabelAndDoesNotRepeatPrompt() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .notDetermined
        fixture.notifications.requestedStatus = .denied
        await fixture.store.notificationStore.requestPermission()
        #expect(fixture.store.notificationStore.authorizationStatus == .denied)
        await fixture.store.notificationStore.requestPermission()
        #expect(fixture.notifications.requestCount == 1)
    }
}

@MainActor
private final class SuspendedNotificationScheduler: NotificationScheduling {
    private var status: UNAuthorizationStatus = .notDetermined
    private var continuation: CheckedContinuation<Bool, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private(set) var requestCount = 0

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        return await withCheckedContinuation {
            continuation = $0
            waiter?.resume()
            waiter = nil
        }
    }
    func waitUntilRequested() async {
        guard continuation == nil else { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func grantPermission() {
        status = .authorized
        continuation?.resume(returning: true)
        continuation = nil
    }
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {}
}
