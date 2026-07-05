import CoreLocation
import Testing
import XCTest
import UserNotifications
@testable import OpenAir

@MainActor
@Test
func successfulForegroundRefreshRecordsSignificantEvent() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-review-success-\(UUID().uuidString).json")
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let appReviewManager = AppReviewManager(userPreferences: userPreferences)
    let store = AppStore(
        weather: WeatherSpy(snapshots: [appStoreTestSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398))),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: appReviewManager
    )

    let result = await store.refresh()

    #expect(result == .succeeded)
    #expect(userPreferences.reviewSignificantEventCount == 1)
}

@MainActor
@Test
func failedForegroundRefreshDoesNotRecordSignificantEvent() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-review-failure-\(UUID().uuidString).json")
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let appReviewManager = AppReviewManager(userPreferences: userPreferences)
    let store = AppStore(
        weather: FailingWeatherProvider(),
        location: LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398))),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: appReviewManager
    )

    let result = await store.refresh()

    #expect(result == .failed)
    #expect(userPreferences.reviewSignificantEventCount == 0)
}

@MainActor
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
    let store = AppStore(
        weather: WeatherSpy(snapshots: [appStoreTestSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: appReviewManager
    )

    let result = await store.refreshForBackground()

    #expect(result == .succeeded)
    #expect(userPreferences.reviewSignificantEventCount == 0)
}

@MainActor
@Test
func previewWeatherDoesNotRecordSignificantEvent() async {
    let userPreferences = InMemoryUserPreferenceStore()
    let appReviewManager = AppReviewManager(userPreferences: userPreferences)
    let store = AppStore(
        weather: WeatherSpy(snapshots: [appStoreTestSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398))),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-review-preview-\(UUID().uuidString).json")),
        userPreferences: userPreferences,
        appReviewManager: appReviewManager
    )

    await store.usePreviewWeather()

    #expect(userPreferences.reviewSignificantEventCount == 0)
}

@MainActor
@Test
func backgroundRefreshUsesLastKnownCurrentLocationWithoutRequestingLocation() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-background-\(UUID().uuidString).json")
    let refreshed = appStoreTestSnapshot(fetchedAt: Date())
    let weather = WeatherSpy(snapshots: [refreshed])
    let location = LocationStub(result: .failure(LocationError.denied))
    let lastKnownCurrentLocation = SavedPlace(
        name: "Wilmington, DE",
        coordinate: .init(latitude: 39.7391, longitude: -75.5398)
    )
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    userPreferences.lastKnownCurrentLocation = lastKnownCurrentLocation
    let store = AppStore(
        weather: weather,
        location: location,
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    let result = await store.refreshForBackground()

    #expect(result == .succeeded)
    #expect(store.refreshState == .idle)
    let fetchCount = await weather.fetchCount
    #expect(fetchCount == 1)
    #expect(location.requestLocationCount == 0)
    guard case .loaded(let snapshot, _) = store.loadState else {
        Issue.record("Expected refreshed weather to be loaded")
        return
    }
    #expect(snapshot.coordinate == lastKnownCurrentLocation.coordinate)
    #expect(snapshot.locationName == lastKnownCurrentLocation.name)
    #expect(snapshot.fetchedAt == refreshed.fetchedAt)
}

@MainActor
@Test
func backgroundRefreshSkipsWhenAutomaticLocationHasNoLastKnownPlace() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-background-empty-\(UUID().uuidString).json")
    let weather = WeatherSpy(snapshots: [appStoreTestSnapshot(fetchedAt: Date())])
    let location = LocationStub(result: .failure(LocationError.denied))
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let store = AppStore(
        weather: weather,
        location: location,
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    let result = await store.refreshForBackground()

    #expect(result == .skipped)
    #expect(store.refreshState == .idle)
    let fetchCount = await weather.fetchCount
    #expect(fetchCount == 0)
    #expect(location.requestLocationCount == 0)
}

@MainActor
@Test
func foregroundRefreshStillFailsDeniedCurrentLocation() async {
    let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-foreground-\(UUID().uuidString).json")
    let userPreferences = InMemoryUserPreferenceStore()
    userPreferences.hasCompletedOnboarding = true
    let store = AppStore(
        weather: WeatherSpy(snapshots: [appStoreTestSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: cacheURL),
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    let result = await store.refresh(keepsLoadedState: true)

    #expect(result == .failed)
    #expect(store.refreshState == .failed)
}

@MainActor
@Test
func completingOnboardingPublishesWidgetSnapshotForSelectedPlace() async {
    let selectedPlace = SavedPlace(
        name: "Wilmington, DE",
        coordinate: .init(latitude: 39.7391, longitude: -75.5398)
    )
    let widgetPublisher = WidgetSnapshotPublisherSpy()
    let userPreferences = InMemoryUserPreferenceStore()
    let store = AppStore(
        weather: WeatherSpy(snapshots: [appStoreTestSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-widget-onboarding-\(UUID().uuidString).json")),
        widgetPublisher: widgetPublisher,
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    store.choose(place: selectedPlace)
    await store.completeOnboarding()

    #expect(widgetPublisher.publishedLocationNames == ["Wilmington, DE"])
}

@MainActor
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
    let store = AppStore(
        weather: WeatherSpy(snapshots: [
            appStoreTestSnapshot(fetchedAt: Date()),
            appStoreTestSnapshot(fetchedAt: Date())
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

    store.choose(place: initialPlace)
    _ = await store.refresh()
    await store.chooseAndRefresh(place: newPlace)

    #expect(widgetPublisher.publishedLocationNames == ["Philadelphia, PA", "Wilmington, DE"])
}

@MainActor
final class AppStoreTests: XCTestCase {
    private let userPreferences = InMemoryUserPreferenceStore()
    private let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-tests-\(UUID().uuidString).json")

    func testManualCityCompletesOnboardingAndLoadsWeather() async {
        let place = SavedPlace(
            name: "Wilmington, DE",
            coordinate: .init(latitude: 39.7, longitude: -75.5)
        )
        let store = makeStore(location: LocationStub(result: .failure(LocationError.denied)))
        store.choose(place: place)

        await store.completeOnboarding()

        XCTAssertTrue(store.hasCompletedOnboarding)
        guard case .loaded(let snapshot, _) = store.loadState else {
            return XCTFail("Expected loaded dashboard state")
        }
        XCTAssertEqual(snapshot.locationName, place.name)

        let restored = makeStore()
        XCTAssertTrue(restored.hasCompletedOnboarding)
        XCTAssertEqual(restored.savedPlace, place)
    }

    func testDeniedCurrentLocationProducesFailureState() async {
        let store = makeStore(location: LocationStub(result: .failure(LocationError.denied)))

        await store.completeOnboarding()

        guard case .failed(let message, _) = store.loadState else {
            return XCTFail("Expected failure state")
        }
        XCTAssertTrue(message.contains("Choose a city"))
    }

    func testCurrentLocationUsesResolvedPlacename() async {
        let location = LocationStub(
            result: .success(.init(latitude: 39.7391, longitude: -75.5398)),
            placename: "Wilmington, DE"
        )
        let store = makeStore(location: location)

        await store.completeOnboarding()

        guard case .loaded(let snapshot, _) = store.loadState else {
            return XCTFail("Expected loaded dashboard state")
        }
        XCTAssertEqual(snapshot.locationName, "Wilmington, DE")
    }

    func testCurrentLocationFallsBackWhenPlacenameIsUnavailable() async {
        let store = makeStore()

        await store.completeOnboarding()

        guard case .loaded(let snapshot, _) = store.loadState else {
            return XCTFail("Expected loaded dashboard state")
        }
        XCTAssertEqual(snapshot.locationName, "Current Location")
    }

    func testUseCurrentLocationRefreshesLoadedManualPlace() async {
        let place = SavedPlace(
            name: "Philadelphia, PA",
            coordinate: .init(latitude: 39.9526, longitude: -75.1652)
        )
        let location = LocationStub(
            result: .success(.init(latitude: 39.7391, longitude: -75.5398)),
            placename: "Wilmington, DE"
        )
        let weather = WeatherSpy(snapshots: [
            Self.snapshot(fetchedAt: Date()),
            Self.snapshot(fetchedAt: Date())
        ])
        let store = makeStore(weather: weather, location: location)
        store.choose(place: place)

        await store.completeOnboarding()

        guard case .loaded(let manualSnapshot, _) = store.loadState else {
            return XCTFail("Expected loaded manual city")
        }
        XCTAssertEqual(manualSnapshot.locationName, "Philadelphia, PA")

        let switchedToCurrentLocation = await store.useCurrentLocation()
        XCTAssertTrue(switchedToCurrentLocation)

        guard case .loaded(let currentSnapshot, _) = store.loadState else {
            return XCTFail("Expected loaded current location")
        }
        XCTAssertEqual(currentSnapshot.locationName, "Wilmington, DE")
        XCTAssertEqual(store.lastKnownCurrentLocation?.name, "Wilmington, DE")
    }

    func testChooseManualPlaceRefreshesLoadedDashboard() async {
        let initialPlace = SavedPlace(
            name: "Philadelphia, PA",
            coordinate: .init(latitude: 39.9526, longitude: -75.1652)
        )
        let newPlace = SavedPlace(
            name: "Wilmington, DE",
            coordinate: .init(latitude: 39.7391, longitude: -75.5398)
        )
        let weather = WeatherSpy(snapshots: [
            Self.snapshot(fetchedAt: Date()),
            Self.snapshot(fetchedAt: Date())
        ])
        let store = makeStore(weather: weather)
        store.choose(place: initialPlace)

        await store.completeOnboarding()

        guard case .loaded(let initialSnapshot, _) = store.loadState else {
            return XCTFail("Expected loaded initial city")
        }
        XCTAssertEqual(initialSnapshot.locationName, "Philadelphia, PA")

        await store.chooseAndRefresh(place: newPlace)

        guard case .loaded(let refreshedSnapshot, _) = store.loadState else {
            return XCTFail("Expected refreshed manual city")
        }
        XCTAssertEqual(refreshedSnapshot.locationName, "Wilmington, DE")
    }

    func testPreferencesPersist() async {
        let store = makeStore()
        var preferences = store.preferences
        preferences.temperatureUnit = .celsius
        preferences.maximumWindMPH = 12
        store.preferences = preferences

        let restored = makeStore()

        XCTAssertEqual(restored.preferences.temperatureUnit, .celsius)
        XCTAssertEqual(restored.preferences.maximumWindMPH, 12)
    }

    func testFirstLaunchDefaultsTemperatureUnitFromMetricLocale() async {
        let store = makeStore(locale: Locale(identifier: "ja_JP"))

        XCTAssertEqual(store.preferences.temperatureUnit, .celsius)
    }

    func testFirstLaunchDefaultsTemperatureUnitFromUSLocale() async {
        let store = makeStore(locale: Locale(identifier: "en_US"))

        XCTAssertEqual(store.preferences.temperatureUnit, .fahrenheit)
    }

    func testSavedTemperatureUnitOverridesLocaleDefault() async {
        var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
        preferences.temperatureUnit = .fahrenheit
        makeUserPreferences(locale: Locale(identifier: "en_US")).preferences = preferences

        let store = makeStore(locale: Locale(identifier: "ja_JP"))

        XCTAssertEqual(store.preferences.temperatureUnit, .fahrenheit)
    }

    func testForegroundRefreshSkipsFreshForecast() async {
        let now = Date()
        let weather = WeatherSpy(snapshots: [Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 14))])
        let store = makeStore(weather: weather)
        store.hasCompletedOnboarding = true

        await store.refresh()
        await store.refreshIfNeeded(now: now)

        let fetchCount = await weather.fetchCount
        XCTAssertEqual(fetchCount, 1)
    }

    func testForegroundRefreshReloadsOldForecast() async {
        let now = Date()
        let weather = WeatherSpy(snapshots: [
            Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 16)),
            Self.snapshot(fetchedAt: now)
        ])
        let store = makeStore(weather: weather)
        store.hasCompletedOnboarding = true

        await store.refresh()
        await store.refreshIfNeeded(now: now)

        let fetchCount = await weather.fetchCount
        XCTAssertEqual(fetchCount, 2)
    }

    func testForegroundRefreshKeepsOldForecastVisibleWhilePending() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.refreshIfNeeded(now: now) }
        await weather.waitUntilFetchStarts()

        XCTAssertEqual(store.refreshState, .refreshing)
        guard case .loaded(let snapshot, _) = store.loadState else {
            refreshTask.cancel()
            return XCTFail("Expected old forecast to remain visible during foreground refresh")
        }
        XCTAssertEqual(snapshot, cached)
        XCTAssertFalse(store.shouldShowStaleBanner(for: snapshot, now: now))

        await weather.resume(returning: Self.snapshot(fetchedAt: now))
        _ = await refreshTask.value
        XCTAssertEqual(store.refreshState, .idle)
    }

    func testFailedRefreshShowsBannerForStaleCachedWeather() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        let result = await store.refresh(keepsLoadedState: true)

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(store.refreshState, .failed)
        XCTAssertTrue(store.shouldShowStaleBanner(for: cached, now: now))
    }

    func testFailedRefreshDoesNotShowBannerForFreshCachedWeather() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        let result = await store.refresh(keepsLoadedState: true)

        XCTAssertEqual(result, .failed)
        XCTAssertFalse(store.shouldShowStaleBanner(for: cached, now: now))
    }

    func testSuccessfulRefreshClearsFailedRefreshBanner() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        let refreshed = Self.snapshot(fetchedAt: now)
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingThenSucceedingWeatherProvider(snapshot: refreshed))
        _ = await store.refresh(keepsLoadedState: true)
        XCTAssertTrue(store.shouldShowStaleBanner(for: cached, now: now))

        let result = await store.refresh(keepsLoadedState: true)

        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(store.refreshState, .idle)
        XCTAssertFalse(store.shouldShowStaleBanner(for: refreshed, now: now))
    }

    func testRetrySuppressesFailedRefreshBannerWhilePending() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = FailingThenSuspendedWeatherProvider()
        let store = makeStore(weather: weather)
        _ = await store.refresh(keepsLoadedState: true)
        XCTAssertTrue(store.shouldShowStaleBanner(for: cached, now: now))

        let retryTask = Task { await store.refresh(keepsLoadedState: true) }
        await weather.waitUntilSecondFetchStarts()

        XCTAssertEqual(store.refreshState, .refreshing)
        XCTAssertFalse(store.shouldShowStaleBanner(for: cached, now: now))

        await weather.resume(returning: Self.snapshot(fetchedAt: now))
        let result = await retryTask.value
        XCTAssertEqual(result, .succeeded)
    }

    func testCachePreservingRefreshReturnsFailureForBackgroundCompletion() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        let result = await store.refresh(keepsLoadedState: true)

        XCTAssertEqual(result, .failed)
        guard case .loaded(let snapshot, _) = store.loadState else {
            return XCTFail("Expected cached weather to remain loaded")
        }
        XCTAssertEqual(snapshot, cached)
    }

    func testCachePreservingRefreshReturnsSuccessForBackgroundCompletion() async {
        let refreshed = Self.snapshot(fetchedAt: Date())
        let store = makeStore(weather: WeatherSpy(snapshots: [refreshed]))

        let result = await store.refresh(keepsLoadedState: true)

        XCTAssertEqual(result, .succeeded)
    }

    func testCachedWeatherIsLoadedImmediatelyAfterInitialization() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()

        let store = makeStore()

        guard case .loaded(let snapshot, _) = store.loadState else {
            return XCTFail("Expected cached dashboard state")
        }
        XCTAssertEqual(snapshot, cached)
    }

    func testStartSkipsRefreshForFreshCachedWeather() async {
        let cached = Self.snapshot(fetchedAt: Date())
        let refreshed = Self.snapshot(fetchedAt: Date().addingTimeInterval(60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = WeatherSpy(snapshots: [refreshed])
        let store = makeStore(weather: weather)

        let result = await store.start()

        let fetchCount = await weather.fetchCount
        XCTAssertEqual(result, .skipped)
        XCTAssertEqual(fetchCount, 0)
        guard case .loaded(let snapshot, _) = store.loadState else {
            return XCTFail("Expected cached dashboard state")
        }
        XCTAssertEqual(snapshot.fetchedAt, cached.fetchedAt)
    }

    func testStartRefreshesStaleCachedWeatherAndKeepsItVisibleWhilePending() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60 * 16))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.start() }
        await weather.waitUntilFetchStarts()

        XCTAssertEqual(store.refreshState, .refreshing)
        guard case .loaded(let snapshot, _) = store.loadState else {
            refreshTask.cancel()
            return XCTFail("Expected cached dashboard state during refresh")
        }
        XCTAssertEqual(snapshot, cached)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        _ = await refreshTask.value
        XCTAssertEqual(store.refreshState, .idle)
    }

    func testPreservingRefreshKeepsLoadedWeatherVisibleWhilePending() async {
        let current = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        let weather = SuspendedWeatherProvider()
        WeatherCache(url: cacheURL).save(current)
        markOnboardingCompleted()
        let restoredStore = makeStore(weather: weather)

        let refreshTask = Task { await restoredStore.refresh(keepsLoadedState: true) }
        await weather.waitUntilFetchStarts()

        XCTAssertEqual(restoredStore.refreshState, .refreshing)
        guard case .loaded(let snapshot, _) = restoredStore.loadState else {
            refreshTask.cancel()
            return XCTFail("Expected loaded weather during preserving refresh")
        }
        XCTAssertEqual(snapshot, current)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        _ = await refreshTask.value
        XCTAssertEqual(restoredStore.refreshState, .idle)
    }

    func testStartWithoutCacheShowsLoadingThenFailure() async {
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.start() }
        await weather.waitUntilFetchStarts()

        guard case .loading = store.loadState else {
            refreshTask.cancel()
            return XCTFail("Expected loading state without cached weather")
        }

        await weather.resume(throwing: WeatherProviderError.unavailable)
        _ = await refreshTask.value

        guard case .failed = store.loadState else {
            return XCTFail("Expected failure state without cached weather")
        }
    }

    func testConcurrentLaunchRefreshesOnlyFetchOnce() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60 * 20))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let startTask = Task { await store.start() }
        await weather.waitUntilFetchStarts()
        await store.refreshIfNeeded()

        let fetchCount = await weather.fetchCount
        XCTAssertEqual(fetchCount, 1)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        _ = await startTask.value
    }

    private func makeStore(
        weather: any WeatherProviding = PreviewWeatherClient(),
        location: any LocationProviding = LocationStub(result: .success(.init(latitude: 0, longitude: 0))),
        locale: Locale = Locale(identifier: "en_US")
    ) -> AppStore {
        AppStore(
            weather: weather,
            location: location,
            places: PlaceSearchStub(),
            evaluator: RecommendationEngine(),
            notifications: NotificationStub(),
            cache: WeatherCache(url: cacheURL),
            userPreferences: makeUserPreferences(locale: locale),
            appReviewManager: AppReviewManager()
        )
    }

    private func makeUserPreferences(
        locale: Locale = Locale(identifier: "en_US")
    ) -> InMemoryUserPreferenceStore {
        userPreferences.applyDefaultPreferences(for: locale)
        return userPreferences
    }

    private func markOnboardingCompleted() {
        makeUserPreferences().hasCompletedOnboarding = true
    }

    private static func snapshot(fetchedAt: Date) -> WeatherSnapshot {
        let base = WeatherSnapshot.preview
        return WeatherSnapshot(
            locationName: base.locationName,
            coordinate: base.coordinate,
            fetchedAt: fetchedAt,
            current: base.current,
            hourly: base.hourly
        )
    }
}

@MainActor
private func appStoreTestSnapshot(fetchedAt: Date) -> WeatherSnapshot {
    let base = WeatherSnapshot.preview
    return WeatherSnapshot(
        locationName: base.locationName,
        coordinate: base.coordinate,
        fetchedAt: fetchedAt,
        current: base.current,
        hourly: base.hourly
    )
}

@MainActor
private final class InMemoryUserPreferenceStore: UserPreferenceStoring {
    var hasCompletedOnboarding = false
    var savedPlace: SavedPlace?
    var lastKnownCurrentLocation: SavedPlace?
    var reviewSignificantEventCount = 0
    var lastReviewRequestAttemptAt: Date?
    private var storedPreferences: ComfortPreferences?

    var preferences: ComfortPreferences {
        get {
            storedPreferences ?? .default(for: Locale(identifier: "en_US"))
        }
        set {
            storedPreferences = newValue
        }
    }

    func applyDefaultPreferences(for locale: Locale) {
        if storedPreferences == nil {
            storedPreferences = .default(for: locale)
        }
    }
}

@MainActor
private final class LocationStub: LocationProviding {
    let result: Result<Coordinate, any Error>
    let placename: String?
    private(set) var requestLocationCount = 0
    var authorizationStatus: CLAuthorizationStatus {
        switch result {
        case .success: .authorizedWhenInUse
        case .failure: .denied
        }
    }

    init(result: Result<Coordinate, any Error>, placename: String? = nil) {
        self.result = result
        self.placename = placename
    }

    func requestAuthorization() {}
    func requestLocation() async throws -> Coordinate {
        requestLocationCount += 1
        return try result.get()
    }
    func placename(for coordinate: Coordinate) async -> String? { placename }
}

private struct PlaceSearchStub: PlaceSearching {
    func search(query: String) async throws -> [SavedPlace] { [] }
}

@MainActor
private final class WidgetSnapshotPublisherSpy: WidgetSnapshotPublishing {
    private(set) var publishedLocationNames: [String] = []

    func publish(
        weather: WeatherSnapshot,
        plan: RecommendationPlan,
        preferences: ComfortPreferences
    ) {
        publishedLocationNames.append(weather.locationName)
    }
}

private actor WeatherSpy: WeatherProviding {
    private let snapshots: [WeatherSnapshot]
    private(set) var fetchCount = 0

    init(snapshots: [WeatherSnapshot]) {
        self.snapshots = snapshots
    }

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        let snapshot = snapshots[min(fetchCount, snapshots.count - 1)]
        fetchCount += 1
        return await WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }
}

private enum WeatherProviderError: Error {
    case unavailable
}

private struct FailingWeatherProvider: WeatherProviding {
    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        throw WeatherProviderError.unavailable
    }
}

private actor FailingThenSucceedingWeatherProvider: WeatherProviding {
    private let snapshot: WeatherSnapshot
    private var fetchCount = 0

    init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
    }

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        defer { fetchCount += 1 }
        guard fetchCount > 0 else {
            throw WeatherProviderError.unavailable
        }
        return await WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }
}

private actor FailingThenSuspendedWeatherProvider: WeatherProviding {
    private var continuation: CheckedContinuation<WeatherSnapshot, any Error>?
    private var secondFetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var fetchCount = 0

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        fetchCount += 1
        guard fetchCount > 1 else {
            throw WeatherProviderError.unavailable
        }

        secondFetchStartedContinuation?.resume()
        secondFetchStartedContinuation = nil
        let snapshot = try await withCheckedThrowingContinuation { continuation = $0 }
        return await WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }

    func waitUntilSecondFetchStarts() async {
        guard fetchCount < 2 else { return }
        await withCheckedContinuation { secondFetchStartedContinuation = $0 }
    }

    func resume(returning snapshot: WeatherSnapshot) {
        continuation?.resume(returning: snapshot)
        continuation = nil
    }
}

private actor SuspendedWeatherProvider: WeatherProviding {
    private var continuation: CheckedContinuation<WeatherSnapshot, any Error>?
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private(set) var fetchCount = 0

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        fetchCount += 1
        fetchStartedContinuation?.resume()
        fetchStartedContinuation = nil
        let snapshot = try await withCheckedThrowingContinuation { continuation = $0 }
        return await WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }

    func waitUntilFetchStarts() async {
        guard fetchCount == 0 else { return }
        await withCheckedContinuation { fetchStartedContinuation = $0 }
    }

    func resume(returning snapshot: WeatherSnapshot) {
        continuation?.resume(returning: snapshot)
        continuation = nil
    }

    func resume(throwing error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

@MainActor
private struct NotificationStub: NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {}
}
