import CoreLocation
import Observation
import Synchronization
import SwiftUI
import Testing
import UserNotifications
@testable import OpenAir

@Test
func coordinatorEnvironmentCanBeOverriddenFromItsUnconfiguredDefault() {
    let preferences = InMemoryUserPreferenceStore()
    let app = AppTestFixture(userPreferences: preferences, appReviewManager: AppReviewManager(userPreferences: preferences))
    var environment = EnvironmentValues()
    #expect(environment.appCoordinator == nil)
    // Writable key paths project the previous value before setting the override, as SwiftUI does.
    environment[keyPath: \.appCoordinator] = app.coordinator
    #expect(environment.appCoordinator === app.coordinator)
}

@Test
func preferenceChangesUpdateForecastWidgetsAndNotificationsThroughCoordinator() async throws {
    let fixture = TravelFixture()
    await fixture.store.coordinator.refresh()
    let previousSchedulingCount = fixture.notifications.names.count
    let previousPlan = try #require(fixture.notifications.plans.last)
    var updated = fixture.preferences.preferences
    updated.maximumWindMPH = 0
    updated.alertsEnabled = false

    fixture.store.coordinator.updatePreferences(updated)
    await fixture.notifications.waitForScheduling(count: previousSchedulingCount + 1)

    guard case .loaded(let snapshot, let plan) = fixture.store.weatherStore.loadState else {
        Issue.record("Expected recalculated weather")
        return
    }
    #expect(fixture.preferences.preferences == updated)
    #expect(plan.current == previousPlan.current)
    #expect(plan != previousPlan)
    #expect(plan.hourly.dropFirst().contains { $0.recommendation.reasons.contains(.windy) })
    #expect(fixture.notifications.plans.last == plan)
    #expect(fixture.notifications.enabledValues.last == false)
    #expect(fixture.widgets.publishedLocationNames == [snapshot.locationName, snapshot.locationName])
    #expect(fixture.weather.fetchCount == 1)
}

@Test
func sharedPreferenceObservationUpdatesOnboardingAndLocationConsumers() {
    let suite = "store-observation-\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = UserPreferenceStore(userDefaults: defaults)
    let app = AppTestFixture(userPreferences: preferences, appReviewManager: AppReviewManager(userPreferences: preferences))
    let locationChanged = Mutex(false)
    let onboardingChanged = Mutex(false)
    withObservationTracking {
        _ = app.locationStore.savedPlace
    } onChange: {
        locationChanged.withLock { $0 = true }
    }
    withObservationTracking {
        _ = preferences.hasCompletedOnboarding
    } onChange: {
        onboardingChanged.withLock { $0 = true }
    }

    app.locationStore.choose(place: SavedPlace(name: "Home", coordinate: .init(latitude: 40, longitude: -75)))
    preferences.hasCompletedOnboarding = true

    #expect(locationChanged.withLock { $0 })
    #expect(onboardingChanged.withLock { $0 })
    #expect(app.locationStore.savedPlace == preferences.savedPlace)
}

@Test
func backgroundExpirationDiscardsPendingLocationWeatherAndEndsExecution() async {
    let fixture = TravelFixture(authorization: .authorizedAlways)
    fixture.weather.suspendNext = true
    fixture.location.onLocationChange?(.init(latitude: 40, longitude: -75))
    await fixture.weather.waitForSuspension()
    #expect(fixture.store.background.isRunning)
    let finished = fixture.notifications.names.count
    let onFinished = fixture.store.weatherStore.onRefreshQueueFinished
    await withCheckedContinuation { continuation in
        fixture.store.weatherStore.onRefreshQueueFinished = {
            onFinished?()
            continuation.resume()
        }
        fixture.store.background.expiration?()
        fixture.weather.resume()
    }

    #expect(!fixture.store.background.isRunning)
    #expect(fixture.store.background.scheduleCount == 1)
    #expect(fixture.notifications.names.count == finished)
    #expect(fixture.widgets.publishedLocationNames.isEmpty)
    #expect(fixture.store.weatherStore.refreshState == .idle)
    guard case .idle = fixture.store.weatherStore.loadState else {
        Issue.record("Expired request should leave no loaded or loading forecast")
        return
    }
}
@Test
func successfulForegroundRefreshRecordsSignificantEvent() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-review-success-\(UUID().uuidString).json")
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let appReviewManager = AppReviewManager(userPreferences: userPreferences)
    let store = AppTestFixture(
        weather: WeatherSpy(snapshots: [testWeatherSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398))),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: appReviewManager
    )

    let result = await store.coordinator.refresh()

    #expect(result == .succeeded)
    #expect(userPreferences.reviewSignificantEventCount == 1)
}
@Test
func failedForegroundRefreshDoesNotRecordSignificantEvent() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-review-failure-\(UUID().uuidString).json")
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let appReviewManager = AppReviewManager(userPreferences: userPreferences)
    let store = AppTestFixture(
        weather: FailingWeatherProvider(),
        location: LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398))),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: appReviewManager
    )

    let result = await store.coordinator.refresh()

    #expect(result == .failed)
    #expect(userPreferences.reviewSignificantEventCount == 0)
}
@Test
func backgroundRefreshDoesNotRecordSignificantEvent() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-review-background-\(UUID().uuidString).json")
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    userPreferences.lastKnownCurrentLocation = SavedPlace(
        name: "Wilmington, DE",
        coordinate: .init(latitude: 39.7391, longitude: -75.5398)
    )
    let appReviewManager = AppReviewManager(userPreferences: userPreferences)
    let store = AppTestFixture(
        weather: WeatherSpy(snapshots: [testWeatherSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: appReviewManager
    )

    let result = await store.coordinator.refreshForBackground()

    #expect(result == .succeeded)
    #expect(userPreferences.reviewSignificantEventCount == 0)
}
@Test
func previewWeatherDoesNotRecordSignificantEvent() async {
    let userPreferences = InMemoryUserPreferenceStore()
    let appReviewManager = AppReviewManager(userPreferences: userPreferences)
    let store = AppTestFixture(
        weather: WeatherSpy(snapshots: [testWeatherSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398))),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-review-preview-\(UUID().uuidString).json")),
        userPreferences: userPreferences,
        appReviewManager: appReviewManager
    )

    await store.weatherStore.usePreviewWeather()

    #expect(userPreferences.reviewSignificantEventCount == 0)
}
@Test
func previewWeatherPublishesWidgetSnapshot() async {
    let widgetPublisher = WidgetSnapshotPublisherSpy()
    let userPreferences = InMemoryUserPreferenceStore()
    let store = AppTestFixture(
        weather: WeatherSpy(snapshots: [testWeatherSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398))),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-preview-widget-\(UUID().uuidString).json")),
        widgetPublisher: widgetPublisher,
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager(userPreferences: userPreferences)
    )

    await store.weatherStore.usePreviewWeather()

    #expect(widgetPublisher.publishedLocationNames == [WeatherSnapshot.preview.locationName])
}
@Test
func backgroundRefreshUsesLastKnownCurrentLocationWithoutRequestingLocation() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-background-\(UUID().uuidString).json")
    let refreshed = testWeatherSnapshot(fetchedAt: Date())
    let weather = WeatherSpy(snapshots: [refreshed])
    let location = LocationStub(result: .failure(LocationError.denied))
    let lastKnownCurrentLocation = SavedPlace(
        name: "Wilmington, DE",
        coordinate: .init(latitude: 39.7391, longitude: -75.5398)
    )
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    userPreferences.lastKnownCurrentLocation = lastKnownCurrentLocation
    let store = AppTestFixture(
        weather: weather,
        location: location,
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    let result = await store.coordinator.refreshForBackground()

    #expect(result == .succeeded)
    #expect(store.weatherStore.refreshState == .idle)
    let fetchCount = await weather.fetchCount
    #expect(fetchCount == 1)
    #expect(location.requestLocationCount == 0)
    guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
        Issue.record("Expected refreshed weather to be loaded")
        return
    }
    #expect(snapshot.coordinate == lastKnownCurrentLocation.coordinate)
    #expect(snapshot.locationName == lastKnownCurrentLocation.name)
    #expect(snapshot.fetchedAt == refreshed.fetchedAt)
}
@Test
func backgroundRefreshSkipsWhenAutomaticLocationHasNoLastKnownPlace() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-background-empty-\(UUID().uuidString).json")
    let weather = WeatherSpy(snapshots: [testWeatherSnapshot(fetchedAt: Date())])
    let location = LocationStub(result: .failure(LocationError.denied))
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let store = AppTestFixture(
        weather: weather,
        location: location,
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    let result = await store.coordinator.refreshForBackground()

    #expect(result == .skipped)
    #expect(store.weatherStore.refreshState == .idle)
    let fetchCount = await weather.fetchCount
    #expect(fetchCount == 0)
    #expect(location.requestLocationCount == 0)
}
@Test
func foregroundRefreshStillFailsDeniedCurrentLocation() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-foreground-\(UUID().uuidString).json")
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let store = AppTestFixture(
        weather: WeatherSpy(snapshots: [testWeatherSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    let result = await store.coordinator.refresh(keepsLoadedState: true)

    #expect(result == .failed)
    #expect(store.weatherStore.refreshState == .failed)
}
@Test
func completingOnboardingPublishesWidgetSnapshotForSelectedPlace() async {
    let selectedPlace = SavedPlace(
        name: "Wilmington, DE",
        coordinate: .init(latitude: 39.7391, longitude: -75.5398)
    )
    let widgetPublisher = WidgetSnapshotPublisherSpy()
    let userPreferences = InMemoryUserPreferenceStore()
    let store = AppTestFixture(
        weather: WeatherSpy(snapshots: [testWeatherSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-widget-onboarding-\(UUID().uuidString).json")),
        widgetPublisher: widgetPublisher,
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    store.locationStore.choose(place: selectedPlace)
    await store.coordinator.completeOnboarding()

    #expect(widgetPublisher.publishedLocationNames == ["Wilmington, DE"])
}
@Test
func choosingManualPlacePublishesWidgetSnapshotAfterRefresh() async {
    let initialPlace = SavedPlace(
        name: "Philadelphia, PA",
        coordinate: .init(latitude: 39.9526, longitude: -75.1652)
    )
    let newPlace = SavedPlace(
        name: "Wilmington, DE",
        coordinate: .init(latitude: 39.7391, longitude: -75.5398)
    )
    let widgetPublisher = WidgetSnapshotPublisherSpy()
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let store = AppTestFixture(
        weather: WeatherSpy(snapshots: [
            testWeatherSnapshot(fetchedAt: Date()),
            testWeatherSnapshot(fetchedAt: Date())
        ]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-widget-manual-\(UUID().uuidString).json")),
        widgetPublisher: widgetPublisher,
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    store.locationStore.choose(place: initialPlace)
    _ = await store.coordinator.refresh()
    await store.coordinator.chooseAndRefresh(place: newPlace)

    #expect(widgetPublisher.publishedLocationNames == ["Philadelphia, PA", "Wilmington, DE"])
}
@Test
func skippedFreshForegroundRefreshRepublishesWidgetSnapshot() async {
    let now = Date()
    let selectedPlace = SavedPlace(
        name: "Wilmington, DE",
        coordinate: .init(latitude: 39.7391, longitude: -75.5398)
    )
    let widgetPublisher = WidgetSnapshotPublisherSpy()
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    userPreferences.savedPlace = selectedPlace
    let store = AppTestFixture(
        weather: WeatherSpy(snapshots: [testWeatherSnapshot(fetchedAt: now.addingTimeInterval(-60 * 14))]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-widget-republish-\(UUID().uuidString).json")),
        widgetPublisher: widgetPublisher,
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    await store.coordinator.refresh()
    let result = await store.coordinator.refreshIfNeeded(now: now)

    #expect(result == .skipped)
    #expect(widgetPublisher.publishedLocationNames == ["Wilmington, DE", "Wilmington, DE"])
}
