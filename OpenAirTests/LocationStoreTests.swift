import CoreLocation
import Testing
import UserNotifications
@testable import OpenAir

@Suite
struct LocationStoreTests {
    private let origin = Coordinate(latitude: 39.7391, longitude: -75.5398)
    private let destination = Coordinate(latitude: 39.95, longitude: -75.16)

    @Test
    func standaloneLocationStoreSignalsSelectionAndFollowingInvalidation() {
        let preferences = InMemoryUserPreferenceStore()
        preferences.hasCompletedOnboarding = true
        let provider = LocationStub(result: .success(origin))
        provider.statusOverride = .authorizedAlways
        let location = LocationStore(provider: provider, places: PlaceSearchStub(), preferences: preferences)
        var resets: [Bool] = []
        location.onContextInvalidated = { resets.append($0) }
        let place = SavedPlace(name: "Home", coordinate: destination)

        location.choose(place: place)
        location.choose(place: place)
        location.followLocationInBackground = false

        #expect(preferences.savedPlace == place)
        #expect(location.selectionVersion == 1)
        #expect(resets == [true, false])
        #expect(!provider.monitoringEnabled)
    }

    @Test(arguments: [false, true])
    func manualSelectionSupersedesPendingCurrentLocation(fails: Bool) async {
        let fixture = TravelFixture()
        let lookup = SuspendedLocationLookup()
        fixture.location.requestHandler = { try await lookup.request() }
        let pending = Task { await fixture.store.coordinator.useCurrentLocation() }
        await lookup.waitUntilRequested()
        #expect(fixture.store.locationStore.selection.isChoosingCurrentLocation)
        let manual = SavedPlace(name: "Chosen city", coordinate: destination)
        await fixture.store.coordinator.chooseAndRefresh(place: manual)
        lookup.finish(fails: fails)
        #expect(await pending.value == false)
        #expect(fixture.store.locationStore.savedPlace == manual)
        #expect(fixture.snapshot?.locationName == "Chosen city")
        #expect(fixture.store.locationStore.selection.errorMessage == nil)
        #expect(!fixture.store.locationStore.selection.isChoosingCurrentLocation)
    }

    @Test(arguments: [false, true])
    func failedAutomaticSwitchPreservesManualCity(completedOnboarding: Bool) async {
        let fixture = TravelFixture(completedOnboarding: completedOnboarding)
        let manual = SavedPlace(name: "Home", coordinate: origin)
        await fixture.store.coordinator.chooseAndRefresh(place: manual)
        fixture.location.result = .failure(LocationError.denied)
        #expect(await fixture.store.coordinator.useCurrentLocation() == false)
        #expect(fixture.store.locationStore.savedPlace == manual)
        #expect(fixture.preferences.savedPlace == manual)
        #expect(!fixture.location.monitoringEnabled)
        #expect(fixture.store.locationStore.selection.errorMessage != nil)
        if completedOnboarding { #expect(fixture.snapshot?.locationName == "Home") }
    }

    @Test(arguments: [CLAuthorizationStatus.denied, .restricted, .authorizedWhenInUse, .authorizedAlways])
    func locationGuidanceDistinguishesBlockedAccess(status: CLAuthorizationStatus) {
        let fixture = TravelFixture()
        fixture.location.onAuthorizationChange?(status)
        #expect(fixture.store.locationStore.locationAccessBlocked == (status == .denied || status == .restricted))
        #expect(!fixture.store.locationStore.showsBackgroundFollowPermissionAlert)
    }

    @Test
    func activationChecksLocationEvenWithFreshWeather() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.location.result = .success(destination)
        let result = await fixture.store.coordinator.refreshOnActivation()
        #expect(result == .succeeded)
        #expect(fixture.location.requestLocationCount == 2)
        #expect(fixture.snapshot?.coordinate == destination)
    }

    @Test
    func smallMovementSkipsWeatherButRetainsLatestLocation() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        let nearby = Coordinate(latitude: origin.latitude + 0.001, longitude: origin.longitude)
        let result = await fixture.store.coordinator.refreshForLocation(nearby)
        #expect(result == .skipped)
        #expect(fixture.snapshot?.coordinate == origin)
        #expect(fixture.preferences.lastKnownCurrentLocation?.coordinate == nearby)
        #expect(fixture.weather.fetchCount == 1)
        #expect(fixture.location.placenameCount == 1)
    }

    @Test(arguments: [999.0, 1_001.0])
    func movementRefreshesOnlyBeyondOneKilometer(meters: Double) async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        let calibration = Coordinate(latitude: origin.latitude + 0.01, longitude: origin.longitude)
        let metersPerDegree = origin.clLocation.distance(from: calibration.clLocation) / 0.01
        let moved = Coordinate(
            latitude: origin.latitude + meters / metersPerDegree,
            longitude: origin.longitude
        )
        let measuredDistance = origin.clLocation.distance(from: moved.clLocation)
        #expect(abs(measuredDistance - meters) < 0.1)

        let result = await fixture.store.coordinator.refreshForLocation(moved)

        #expect(result == (meters < 1_000 ? .skipped : .succeeded))
        #expect(fixture.weather.fetchCount == (meters < 1_000 ? 1 : 2))
        #expect(fixture.location.placenameCount == (meters < 1_000 ? 1 : 2))
        #expect(fixture.preferences.lastKnownCurrentLocation?.coordinate == moved)
    }

    @Test(arguments: [14 * 60 + 59.0, 15 * 60 + 1.0])
    func activationRefreshesAtFifteenMinuteBoundary(age: Double) async {
        let cached = WeatherSnapshot(
            locationName: "Travel city",
            coordinate: origin,
            fetchedAt: Date.now.addingTimeInterval(-age),
            current: WeatherSnapshot.preview.current,
            hourly: WeatherSnapshot.preview.hourly
        )
        let fixture = TravelFixture(cachedSnapshot: cached)

        let result = await fixture.store.coordinator.refreshOnActivation()

        #expect(result == (age < 15 * 60 ? .skipped : .succeeded))
        #expect(fixture.location.requestLocationCount == 1)
        #expect(fixture.weather.fetchCount == (age < 15 * 60 ? 0 : 1))
        #expect(fixture.location.placenameCount == (age < 15 * 60 ? 0 : 1))
    }

    @Test
    func movementPublishesWeatherWidgetsAndNotificationsWithoutRequestingLocationOrReview() async {
        let fixture = TravelFixture()
        fixture.location.statusOverride = .authorizedAlways
        fixture.location.onAuthorizationChange?(.authorizedAlways)
        await fixture.store.coordinator.refreshForLocation(destination)
        #expect(fixture.location.requestLocationCount == 0)
        #expect(fixture.snapshot?.coordinate == destination)
        #expect(fixture.widgets.publishedLocationNames == ["Travel city"])
        #expect(fixture.notifications.names == ["Travel city"])
        #expect(fixture.preferences.reviewSignificantEventCount == 0)
    }

    @Test
    func manualCityStopsMonitoringAndIgnoresMovement() async {
        let fixture = TravelFixture()
        fixture.location.statusOverride = .authorizedAlways
        fixture.location.onAuthorizationChange?(.authorizedAlways)
        fixture.store.locationStore.followLocationInBackground = true
        fixture.store.coordinator.setForeground(true)
        #expect(fixture.location.monitoringEnabled)
        let manual = SavedPlace(name: "Home", coordinate: origin)
        await fixture.store.coordinator.chooseAndRefresh(place: manual)
        #expect(!fixture.location.monitoringEnabled)
        #expect(!fixture.store.locationStore.showsBackgroundFollowPermissionAlert)
        #expect(await fixture.store.coordinator.refreshForLocation(destination) == .skipped)
        #expect(fixture.snapshot?.coordinate == origin)
        #expect(fixture.location.requestLocationCount == 0)
    }

    @Test
    func enablingBackgroundFollowingRequestsAlwaysOnlyFromSettings() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.store.coordinator.setForeground(true)
        #expect(fixture.location.alwaysRequests == 0)
        #expect(!fixture.store.locationStore.followLocationInBackground)
        fixture.store.locationStore.followLocationInBackground = true
        #expect(!fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.preferences.followLocationInBackground == false)
        #expect(!fixture.store.locationStore.showsBackgroundFollowPermissionAlert)
        #expect(fixture.preferences.hasRequestedAlwaysLocationAccess)
        #expect(fixture.location.alwaysRequests == 1)
        #expect(!fixture.location.monitoringEnabled)
        fixture.location.statusOverride = .authorizedAlways
        fixture.location.onAuthorizationChange?(.authorizedAlways)
        #expect(fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.location.monitoringEnabled)
        #expect(!fixture.store.locationStore.showsBackgroundFollowPermissionAlert)
        fixture.store.locationStore.followLocationInBackground = false
        #expect(!fixture.location.monitoringEnabled)
        fixture.location.statusOverride = .denied
        fixture.location.onAuthorizationChange?(.denied)
        #expect(fixture.store.locationStore.locationAccessBlocked)
        #expect(await fixture.store.coordinator.refreshForLocation(destination) == .skipped)
    }

    @Test
    func declinedAlwaysPermissionLeavesFollowingOff() {
        let fixture = TravelFixture()
        fixture.store.coordinator.setForeground(true)
        fixture.store.locationStore.followLocationInBackground = true
        #expect(fixture.location.alwaysRequests == 1)
        fixture.store.coordinator.setForeground(true) // returning after declining the permission prompt
        #expect(!fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.preferences.followLocationInBackground == false)
        #expect(!fixture.location.monitoringEnabled)
        #expect(fixture.store.locationStore.showsBackgroundFollowPermissionAlert)
        fixture.store.locationStore.dismissBackgroundFollowPermissionAlert()
        #expect(!fixture.store.locationStore.showsBackgroundFollowPermissionAlert)
        fixture.store.locationStore.followLocationInBackground = true
        #expect(fixture.store.locationStore.showsBackgroundFollowPermissionAlert)
        #expect(fixture.location.alwaysRequests == 1)
    }

    @Test
    func grantingAlwaysInSettingsCompletesBackgroundFollowingRequest() {
        let fixture = TravelFixture()
        fixture.store.coordinator.setForeground(true)
        fixture.store.locationStore.followLocationInBackground = true
        fixture.store.coordinator.setForeground(true) // The system prompt kept When In Use access.
        #expect(fixture.store.locationStore.showsBackgroundFollowPermissionAlert)

        fixture.store.locationStore.enableBackgroundFollowingAfterSettings()
        #expect(!fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.preferences.followLocationInBackground == true)
        #expect(!fixture.location.monitoringEnabled)

        fixture.store.coordinator.setForeground(false)
        fixture.location.statusOverride = .authorizedAlways
        fixture.location.onAuthorizationChange?(.authorizedAlways)
        fixture.store.coordinator.setForeground(true)

        #expect(fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.location.monitoringEnabled)
    }

    @Test
    func returningFromSettingsWithoutAlwaysKeepsFollowingOff() {
        let fixture = TravelFixture()
        fixture.store.coordinator.setForeground(true)
        fixture.store.locationStore.followLocationInBackground = true
        fixture.store.coordinator.setForeground(true)
        fixture.store.locationStore.enableBackgroundFollowingAfterSettings()

        fixture.store.coordinator.setForeground(false)
        fixture.store.coordinator.setForeground(true)

        #expect(!fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.preferences.followLocationInBackground == false)
        #expect(!fixture.location.monitoringEnabled)
    }

    @Test
    func settingsHandoffSurvivesAppRestartAfterAlwaysIsGranted() {
        let preferences = InMemoryUserPreferenceStore()
        preferences.hasCompletedOnboarding = true
        let before = LocationStub(result: .success(origin), placename: "Travel city")
        let originalController = LocationFollowController(location: before, preferences: preferences)
        originalController.enableFollowingAfterSettings()
        #expect(preferences.followLocationInBackground == true)

        let after = LocationStub(result: .success(origin), placename: "Travel city")
        after.statusOverride = .authorizedAlways
        let restoredController = LocationFollowController(location: after, preferences: preferences)
        restoredController.setEligible(true)

        #expect(restoredController.isFollowing)
        #expect(after.monitoringEnabled)
    }

    @Test
    func alreadyDeniedBackgroundFollowingShowsSettingsAlertWithoutRequestingAgain() {
        let fixture = TravelFixture()
        fixture.preferences.hasRequestedAlwaysLocationAccess = true
        fixture.store.locationStore.followLocationInBackground = true
        #expect(!fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.store.locationStore.showsBackgroundFollowPermissionAlert)
        #expect(fixture.location.alwaysRequests == 0)
    }

    @Test
    func revokedAlwaysPermissionTurnsFollowingOff() {
        let fixture = TravelFixture(authorization: .authorizedAlways)
        #expect(fixture.store.locationStore.followLocationInBackground)
        fixture.location.statusOverride = .authorizedWhenInUse
        fixture.location.onAuthorizationChange?(.authorizedWhenInUse)
        #expect(!fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.preferences.followLocationInBackground == false)
        #expect(!fixture.location.monitoringEnabled)
    }

    @Test
    func newUserDoesNotRequestAlwaysDuringOnboardingOrActivation() async {
        let fixture = TravelFixture(completedOnboarding: false)
        fixture.store.coordinator.setForeground(true)
        await fixture.store.coordinator.completeOnboarding()
        await fixture.store.coordinator.refreshOnActivation()
        fixture.store.coordinator.setForeground(false)
        await fixture.store.coordinator.refreshOnActivation()
        #expect(!fixture.store.locationStore.followLocationInBackground)
        #expect(fixture.location.alwaysRequests == 0)
    }

    @Test
    func existingAlwaysUserStartsWithBackgroundFollowingOn() {
        let fixture = TravelFixture(authorization: .authorizedAlways)
        #expect(fixture.store.locationStore.followLocationInBackground)
        fixture.store.coordinator.synchronizeLocationMonitoring()
        #expect(fixture.location.monitoringEnabled)
        #expect(fixture.location.alwaysRequests == 0)
    }

    @Test
    func foregroundChecksLocationButDoesNotFetchWhileStationary() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.store.coordinator.setForeground(true)
        let result = await fixture.store.coordinator.checkForegroundLocation()
        #expect(result == .skipped)
        #expect(fixture.location.requestLocationCount == 2)
        #expect(fixture.weather.fetchCount == 1)
        #expect(fixture.location.placenameCount == 1)
        #expect(!fixture.location.monitoringEnabled)
    }

    @Test
    func foregroundMovementFetchesWeather() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.store.coordinator.setForeground(true)
        fixture.location.result = .success(destination)
        #expect(await fixture.store.coordinator.checkForegroundLocation() == .succeeded)
        #expect(fixture.weather.fetchCount == 2)
        #expect(fixture.location.placenameCount == 2)
    }

    @Test
    func travelDetectedOnReturnKeepsBackgroundFollowTipUntilDismissed() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.location.result = .success(destination)

        #expect(await fixture.store.coordinator.refreshOnActivation() == .succeeded)
        #expect(fixture.snapshot?.coordinate == destination)
        #expect(fixture.store.locationStore.showsBackgroundFollowTip)
        #expect(fixture.preferences.backgroundFollowTipState == .pending)
        #expect(fixture.location.alwaysRequests == 0)

        await fixture.store.coordinator.refreshOnActivation()
        #expect(fixture.store.locationStore.showsBackgroundFollowTip)

        fixture.store.coordinator.setForeground(false)
        #expect(!fixture.store.locationStore.showsBackgroundFollowTip)
        await fixture.store.coordinator.refreshOnActivation()
        #expect(fixture.store.locationStore.showsBackgroundFollowTip)
        #expect(fixture.preferences.backgroundFollowTipState == .pending)
    }

    @Test
    func dismissingTravelTipHidesItImmediately() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.location.result = .success(destination)
        await fixture.store.coordinator.refreshOnActivation()
        #expect(fixture.store.locationStore.showsBackgroundFollowTip)

        fixture.store.locationStore.dismissBackgroundFollowTip()
        #expect(!fixture.store.locationStore.showsBackgroundFollowTip)
        #expect(fixture.preferences.backgroundFollowTipState == .consumed)
    }

    @Test
    func pendingTravelTipSurvivesAppRelaunch() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.location.result = .success(destination)
        await fixture.store.coordinator.refreshOnActivation()

        let relaunchedStore = AppTestFixture(
            weather: TravelWeatherProvider(),
            location: LocationStub(result: .success(destination), placename: "Travel city"),
            places: PlaceSearchStub(),
            notifications: NotificationStub(),
            cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "travel-relaunch-\(UUID()).json")),
            userPreferences: fixture.preferences,
            appReviewManager: AppReviewManager(userPreferences: fixture.preferences)
        )

        #expect(await relaunchedStore.coordinator.refreshOnActivation() == .succeeded)
        #expect(relaunchedStore.locationStore.showsBackgroundFollowTip)
        #expect(fixture.preferences.backgroundFollowTipState == .pending)
    }

    @Test
    func foregroundTravelQueuesTipUntilNextVisit() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.store.coordinator.setForeground(true)
        fixture.location.result = .success(destination)

        #expect(await fixture.store.coordinator.checkForegroundLocation() == .succeeded)
        #expect(fixture.preferences.backgroundFollowTipState == .pending)
        #expect(!fixture.store.locationStore.showsBackgroundFollowTip)

        fixture.store.coordinator.setForeground(false)
        #expect(await fixture.store.coordinator.refreshOnActivation() == .skipped)
        #expect(fixture.store.locationStore.showsBackgroundFollowTip)
        #expect(fixture.preferences.backgroundFollowTipState == .pending)
        #expect(fixture.weather.fetchCount == 2)
    }

    @Test
    func shortMoveAndFailedTravelFetchDoNotQueueTip() async {
        let shortMove = TravelFixture()
        await shortMove.store.coordinator.refresh()
        shortMove.location.result = .success(Coordinate(latitude: origin.latitude + 0.001, longitude: origin.longitude))
        #expect(await shortMove.store.coordinator.refreshOnActivation() == .skipped)
        #expect(shortMove.preferences.backgroundFollowTipState == .tracking(origin))

        let failedMove = TravelFixture()
        await failedMove.store.coordinator.refresh()
        failedMove.weather.fails = true
        failedMove.location.result = .success(destination)
        #expect(await failedMove.store.coordinator.refreshOnActivation() == .failed)
        #expect(failedMove.preferences.backgroundFollowTipState == .tracking(origin))
        #expect(!failedMove.store.locationStore.showsBackgroundFollowTip)

        failedMove.weather.fails = false
        #expect(await failedMove.store.coordinator.refreshOnActivation() == .succeeded)
        #expect(failedMove.store.locationStore.showsBackgroundFollowTip)
    }

    @Test
    func severalShortMovesAccumulateTowardTravelTip() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refresh()
        fixture.store.coordinator.setForeground(true)
        let firstMove = Coordinate(latitude: origin.latitude + 0.025, longitude: origin.longitude)
        let secondMove = Coordinate(latitude: origin.latitude + 0.055, longitude: origin.longitude)

        #expect(await fixture.store.coordinator.refreshForLocation(firstMove) == .succeeded)
        #expect(fixture.preferences.backgroundFollowTipState == .tracking(origin))
        #expect(await fixture.store.coordinator.refreshForLocation(secondMove) == .succeeded)
        #expect(fixture.preferences.backgroundFollowTipState == .pending)
        #expect(!fixture.store.locationStore.showsBackgroundFollowTip)
    }

    @Test
    func manualCityAndPriorPermissionChoiceSuppressTravelTip() async {
        let manualCity = TravelFixture()
        await manualCity.store.coordinator.refresh()
        manualCity.store.coordinator.setForeground(true)
        manualCity.location.result = .success(destination)
        await manualCity.store.coordinator.checkForegroundLocation()
        #expect(manualCity.preferences.backgroundFollowTipState == .pending)
        await manualCity.store.coordinator.chooseAndRefresh(place: SavedPlace(name: "Home", coordinate: origin))
        #expect(manualCity.preferences.backgroundFollowTipState == .uninitialized)
        manualCity.store.coordinator.setForeground(false)
        await manualCity.store.coordinator.refreshOnActivation()
        #expect(!manualCity.store.locationStore.showsBackgroundFollowTip)

        let priorChoice = TravelFixture()
        priorChoice.preferences.hasRequestedAlwaysLocationAccess = true
        await priorChoice.store.coordinator.refresh()
        priorChoice.location.result = .success(destination)
        #expect(await priorChoice.store.coordinator.refreshOnActivation() == .succeeded)
        #expect(priorChoice.preferences.backgroundFollowTipState == .uninitialized)
        #expect(!priorChoice.store.locationStore.showsBackgroundFollowTip)
    }

    @Test
    func launchRestoresMonitoringWithoutForegroundPermissionPrompt() {
        let fixture = TravelFixture(authorization: .authorizedAlways)
        fixture.store.coordinator.synchronizeLocationMonitoring()
        #expect(fixture.location.monitoringEnabled)
        #expect(!fixture.location.monitoringForeground)
        #expect(fixture.location.alwaysRequests == 0)
        #expect(fixture.location.requestLocationCount == 0)
    }

    @Test
    func newestMovementSurvivesAnInFlightFetch() async {
        let fixture = TravelFixture()
        fixture.weather.suspendNext = true
        let initial = Task { await fixture.store.coordinator.refreshForLocation(origin) }
        await fixture.weather.waitForSuspension()
        await fixture.store.coordinator.refreshForLocation(Coordinate(latitude: 39.8, longitude: -75.3))
        await fixture.store.coordinator.refreshForLocation(destination)
        fixture.weather.resume()
        _ = await initial.value
        #expect(fixture.weather.coordinates == [origin, destination])
        #expect(fixture.snapshot?.coordinate == destination)
    }

    @Test
    func cityChangeDiscardsOldWeatherAndRefreshesSelectedCity() async {
        let fixture = TravelFixture()
        fixture.weather.suspendNext = true
        let initial = Task { await fixture.store.coordinator.refreshForLocation(origin) }
        await fixture.weather.waitForSuspension()
        await fixture.store.coordinator.chooseAndRefresh(place: SavedPlace(name: "Selected city", coordinate: destination))
        fixture.weather.resume()
        _ = await initial.value
        #expect(fixture.snapshot?.coordinate == destination)
        #expect(fixture.widgets.publishedLocationNames == ["Selected city"])
        #expect(fixture.notifications.names == ["Selected city"])
    }

    @Test
    func revokedPermissionDiscardsInFlightLocationWeather() async {
        let fixture = TravelFixture()
        fixture.weather.suspendNext = true
        let initial = Task { await fixture.store.coordinator.refreshForLocation(origin) }
        await fixture.weather.waitForSuspension()
        fixture.location.statusOverride = .denied
        fixture.location.onAuthorizationChange?(.denied)
        fixture.weather.resume()
        _ = await initial.value
        #expect(fixture.widgets.publishedLocationNames.isEmpty)
        #expect(fixture.notifications.names.isEmpty)
        guard case .failed = fixture.store.weatherStore.loadState else {
            Issue.record("Revoked permission must not leave an invalidated request loading")
            return
        }
    }

    @Test
    func failedTravelRefreshPreservesWeatherAndRetriesAtLatestLocation() async {
        let fixture = TravelFixture()
        await fixture.store.coordinator.refreshForLocation(origin)
        fixture.weather.fails = true
        #expect(await fixture.store.coordinator.refreshForLocation(destination) == .failed)
        #expect(fixture.snapshot?.coordinate == origin)
        #expect(fixture.preferences.lastKnownCurrentLocation?.coordinate == destination)
        fixture.weather.fails = false
        #expect(await fixture.store.coordinator.refreshForBackground() == .succeeded)
        #expect(fixture.snapshot?.coordinate == destination)
        #expect(fixture.location.requestLocationCount == 0)
    }
}
