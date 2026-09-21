import CoreLocation
import Testing
import UserNotifications
@testable import OpenAir
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
@Test
func previewWeatherPublishesWidgetSnapshot() async {
    let widgetPublisher = WidgetSnapshotPublisherSpy()
    let userPreferences = InMemoryUserPreferenceStore()
    let store = AppStore(
        weather: WeatherSpy(snapshots: [appStoreTestSnapshot(fetchedAt: Date())]),
        location: LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398))),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-preview-widget-\(UUID().uuidString).json")),
        widgetPublisher: widgetPublisher,
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager(userPreferences: userPreferences)
    )

    await store.usePreviewWeather()

    #expect(widgetPublisher.publishedLocationNames == [WeatherSnapshot.preview.locationName])
}
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
    let store = AppStore(
        weather: WeatherSpy(snapshots: [appStoreTestSnapshot(fetchedAt: now.addingTimeInterval(-60 * 14))]),
        location: LocationStub(result: .failure(LocationError.denied)),
        places: PlaceSearchStub(),
        evaluator: RecommendationEngine(),
        notifications: NotificationStub(),
        cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "openair-widget-republish-\(UUID().uuidString).json")),
        widgetPublisher: widgetPublisher,
        userPreferences: userPreferences,
        appReviewManager: AppReviewManager()
    )

    await store.refresh()
    let result = await store.refreshIfNeeded(now: now)

    #expect(result == .skipped)
    #expect(widgetPublisher.publishedLocationNames == ["Wilmington, DE", "Wilmington, DE"])
}
@Suite
struct AppStoreTests {
    private let userPreferences = InMemoryUserPreferenceStore()
    private let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-tests-\(UUID().uuidString).json")

    @Test
    func testManualCityCompletesOnboardingAndLoadsWeather() async {
        let place = SavedPlace(
            name: "Wilmington, DE",
            coordinate: .init(latitude: 39.7, longitude: -75.5)
        )
        let store = makeStore(location: LocationStub(result: .failure(LocationError.denied)))
        store.choose(place: place)

        await store.completeOnboarding()

        #expect(store.hasCompletedOnboarding)
        guard case .loaded(let snapshot, _) = store.loadState else {
            Issue.record("Expected loaded dashboard state")
            return
        }
        #expect(snapshot.locationName == place.name)

        let restored = makeStore()
        #expect(restored.hasCompletedOnboarding)
        #expect(restored.savedPlace == place)
    }

    @Test
    func testDeniedCurrentLocationProducesFailureState() async {
        let store = makeStore(location: LocationStub(result: .failure(LocationError.denied)))

        await store.completeOnboarding()

        guard case .failed(let message, _) = store.loadState else {
            Issue.record("Expected failure state")
            return
        }
        #expect(message.contains("Choose a city"))
    }

    @Test
    func testCurrentLocationUsesResolvedPlacename() async {
        let location = LocationStub(
            result: .success(.init(latitude: 39.7391, longitude: -75.5398)),
            placename: "Wilmington, DE"
        )
        let store = makeStore(location: location)

        await store.completeOnboarding()

        guard case .loaded(let snapshot, _) = store.loadState else {
            Issue.record("Expected loaded dashboard state")
            return
        }
        #expect(snapshot.locationName == "Wilmington, DE")
    }

    @Test
    func testCurrentLocationFallsBackWhenPlacenameIsUnavailable() async {
        let store = makeStore()

        await store.completeOnboarding()

        guard case .loaded(let snapshot, _) = store.loadState else {
            Issue.record("Expected loaded dashboard state")
            return
        }
        #expect(snapshot.locationName == "Current Location")
    }

    @Test
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
            Issue.record("Expected loaded manual city")
            return
        }
        #expect(manualSnapshot.locationName == "Philadelphia, PA")

        let switchedToCurrentLocation = await store.useCurrentLocation()
        #expect(switchedToCurrentLocation)

        guard case .loaded(let currentSnapshot, _) = store.loadState else {
            Issue.record("Expected loaded current location")
            return
        }
        #expect(currentSnapshot.locationName == "Wilmington, DE")
        #expect(store.lastKnownCurrentLocation?.name == "Wilmington, DE")
    }

    @Test
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
            Issue.record("Expected loaded initial city")
            return
        }
        #expect(initialSnapshot.locationName == "Philadelphia, PA")

        await store.chooseAndRefresh(place: newPlace)

        guard case .loaded(let refreshedSnapshot, _) = store.loadState else {
            Issue.record("Expected refreshed manual city")
            return
        }
        #expect(refreshedSnapshot.locationName == "Wilmington, DE")
    }

    @Test
    func testPreferencesPersist() async {
        let store = makeStore()
        var preferences = store.preferences
        preferences.temperatureUnit = .celsius
        preferences.maximumWindMPH = 12
        store.preferences = preferences

        let restored = makeStore()

        #expect(restored.preferences.temperatureUnit == .celsius)
        #expect(restored.preferences.maximumWindMPH == 12)
    }

    @Test
    func testFirstLaunchDefaultsTemperatureUnitFromMetricLocale() async {
        let store = makeStore(locale: Locale(identifier: "ja_JP"))

        #expect(store.preferences.temperatureUnit == .celsius)
    }

    @Test
    func testFirstLaunchDefaultsTemperatureUnitFromUSLocale() async {
        let store = makeStore(locale: Locale(identifier: "en_US"))

        #expect(store.preferences.temperatureUnit == .fahrenheit)
    }

    @Test
    func testSavedTemperatureUnitOverridesLocaleDefault() async {
        var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
        preferences.temperatureUnit = .fahrenheit
        makeUserPreferences(locale: Locale(identifier: "en_US")).preferences = preferences

        let store = makeStore(locale: Locale(identifier: "ja_JP"))

        #expect(store.preferences.temperatureUnit == .fahrenheit)
    }

    @Test
    func testForegroundRefreshSkipsFreshForecast() async {
        let now = Date()
        let weather = WeatherSpy(snapshots: [Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 14))])
        let store = makeStore(weather: weather)
        store.hasCompletedOnboarding = true

        await store.refresh()
        await store.refreshIfNeeded(now: now)

        let fetchCount = await weather.fetchCount
        #expect(fetchCount == 1)
    }

    @Test
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
        #expect(fetchCount == 2)
    }

    @Test
    func testForegroundRefreshKeepsOldForecastVisibleWhilePending() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.refreshIfNeeded(now: now) }
        await weather.waitUntilFetchStarts()

        #expect(store.refreshState == .refreshing)
        guard case .loaded(let snapshot, _) = store.loadState else {
            refreshTask.cancel()
            Issue.record("Expected old forecast to remain visible during foreground refresh")
            return
        }
        #expect(snapshot == cached)
        #expect(!store.shouldShowStaleBanner(for: snapshot, now: now))

        await weather.resume(returning: Self.snapshot(fetchedAt: now))
        _ = await refreshTask.value
        #expect(store.refreshState == .idle)
    }

    @Test
    func testFailedRefreshShowsBannerForStaleCachedWeather() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        let result = await store.refresh(keepsLoadedState: true)

        #expect(result == .failed)
        #expect(store.refreshState == .failed)
        #expect(store.shouldShowStaleBanner(for: cached, now: now))
    }

    @Test
    func testFailedRefreshDoesNotShowBannerForFreshCachedWeather() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        let result = await store.refresh(keepsLoadedState: true)

        #expect(result == .failed)
        #expect(!store.shouldShowStaleBanner(for: cached, now: now))
    }

    @Test
    func testSuccessfulRefreshClearsFailedRefreshBanner() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        let refreshed = Self.snapshot(fetchedAt: now)
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingThenSucceedingWeatherProvider(snapshot: refreshed))
        _ = await store.refresh(keepsLoadedState: true)
        #expect(store.shouldShowStaleBanner(for: cached, now: now))

        let result = await store.refresh(keepsLoadedState: true)

        #expect(result == .succeeded)
        #expect(store.refreshState == .idle)
        #expect(!store.shouldShowStaleBanner(for: refreshed, now: now))
    }

    @Test
    func testRetrySuppressesFailedRefreshBannerWhilePending() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = FailingThenSuspendedWeatherProvider()
        let store = makeStore(weather: weather)
        _ = await store.refresh(keepsLoadedState: true)
        #expect(store.shouldShowStaleBanner(for: cached, now: now))

        let retryTask = Task { await store.refresh(keepsLoadedState: true) }
        await weather.waitUntilSecondFetchStarts()

        #expect(store.refreshState == .refreshing)
        #expect(!store.shouldShowStaleBanner(for: cached, now: now))

        await weather.resume(returning: Self.snapshot(fetchedAt: now))
        let result = await retryTask.value
        #expect(result == .succeeded)
    }

    @Test
    func testCachePreservingRefreshReturnsFailureForBackgroundCompletion() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        let result = await store.refresh(keepsLoadedState: true)

        #expect(result == .failed)
        guard case .loaded(let snapshot, _) = store.loadState else {
            Issue.record("Expected cached weather to remain loaded")
            return
        }
        #expect(snapshot == cached)
    }

    @Test
    func testCachePreservingRefreshReturnsSuccessForBackgroundCompletion() async {
        let refreshed = Self.snapshot(fetchedAt: Date())
        let store = makeStore(weather: WeatherSpy(snapshots: [refreshed]))

        let result = await store.refresh(keepsLoadedState: true)

        #expect(result == .succeeded)
    }

    @Test
    func testCachedWeatherIsLoadedImmediatelyAfterInitialization() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()

        let store = makeStore()

        guard case .loaded(let snapshot, _) = store.loadState else {
            Issue.record("Expected cached dashboard state")
            return
        }
        #expect(snapshot == cached)
    }

    @Test
    func testStartSkipsRefreshForFreshCachedWeather() async {
        let cached = Self.snapshot(fetchedAt: Date())
        let refreshed = Self.snapshot(fetchedAt: Date().addingTimeInterval(60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = WeatherSpy(snapshots: [refreshed])
        let location = LocationStub(result: .success(cached.coordinate))
        let store = makeStore(weather: weather, location: location)

        let result = await store.start()

        let fetchCount = await weather.fetchCount
        #expect(result == .skipped)
        #expect(fetchCount == 0)
        #expect(location.requestLocationCount == 1)
        guard case .loaded(let snapshot, _) = store.loadState else {
            Issue.record("Expected cached dashboard state")
            return
        }
        #expect(snapshot.fetchedAt == cached.fetchedAt)
    }

    @Test
    func testStartRefreshesStaleCachedWeatherAndKeepsItVisibleWhilePending() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60 * 16))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.start() }
        await weather.waitUntilFetchStarts()

        #expect(store.refreshState == .refreshing)
        guard case .loaded(let snapshot, _) = store.loadState else {
            refreshTask.cancel()
            Issue.record("Expected cached dashboard state during refresh")
            return
        }
        #expect(snapshot == cached)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        _ = await refreshTask.value
        #expect(store.refreshState == .idle)
    }

    @Test
    func testPreservingRefreshKeepsLoadedWeatherVisibleWhilePending() async {
        let current = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        let weather = SuspendedWeatherProvider()
        WeatherCache(url: cacheURL).save(current)
        markOnboardingCompleted()
        let restoredStore = makeStore(weather: weather)

        let refreshTask = Task { await restoredStore.refresh(keepsLoadedState: true) }
        await weather.waitUntilFetchStarts()

        #expect(restoredStore.refreshState == .refreshing)
        guard case .loaded(let snapshot, _) = restoredStore.loadState else {
            refreshTask.cancel()
            Issue.record("Expected loaded weather during preserving refresh")
            return
        }
        #expect(snapshot == current)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        _ = await refreshTask.value
        #expect(restoredStore.refreshState == .idle)
    }

    @Test
    func testStartWithoutCacheShowsLoadingThenFailure() async {
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.start() }
        await weather.waitUntilFetchStarts()

        guard case .loading = store.loadState else {
            refreshTask.cancel()
            Issue.record("Expected loading state without cached weather")
            return
        }

        await weather.resume(throwing: WeatherProviderError.unavailable)
        _ = await refreshTask.value

        guard case .failed = store.loadState else {
            Issue.record("Expected failure state without cached weather")
            return
        }
    }

    @Test
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
        #expect(fetchCount == 1)

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
private final class InMemoryUserPreferenceStore: UserPreferenceStoring {
    var hasExplainedBackgroundLocation = false
    var hasCompletedOnboarding = false
    var savedPlace: SavedPlace?
    var lastKnownCurrentLocation: SavedPlace?
    var forecastRange = ForecastRange.tenDays
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
private final class LocationStub: LocationProviding {
    var onLocationChange: ((Coordinate) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    private(set) var alwaysRequests = 0
    private(set) var monitoringEnabled = false
    private(set) var monitoringForeground = false
    var statusOverride: CLAuthorizationStatus?
    func requestAlwaysAuthorization() { alwaysRequests += 1 }
    func setMonitoring(enabled: Bool, foreground: Bool) {
        monitoringEnabled = enabled
        monitoringForeground = foreground
    }

    var result: Result<Coordinate, any Error>
    let placename: String?
    var requestHandler: (() async throws -> Coordinate)?
    private(set) var requestLocationCount = 0
    var authorizationStatus: CLAuthorizationStatus {
        if let statusOverride { return statusOverride }
        switch result {
        case .success: return .authorizedWhenInUse
        case .failure: return .denied
        }
    }

    init(result: Result<Coordinate, any Error>, placename: String? = nil) {
        self.result = result
        self.placename = placename
    }

    func requestAuthorization() {}
    func requestLocation() async throws -> Coordinate {
        requestLocationCount += 1
        if let requestHandler { return try await requestHandler() }
        return try result.get()
    }
    func placename(for coordinate: Coordinate) async -> String? { placename }
}

private struct PlaceSearchStub: PlaceSearching {
    func search(query: String) async throws -> [SavedPlace] { [] }
}
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
private struct NotificationStub: NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {}
}

@Suite
struct AutomaticLocationTests {
    private let origin = Coordinate(latitude: 39.7391, longitude: -75.5398)
    private let destination = Coordinate(latitude: 39.95, longitude: -75.16)

    @Test(arguments: [false, true])
    func manualSelectionSupersedesPendingCurrentLocation(fails: Bool) async {
        let fixture = TravelFixture()
        let lookup = SuspendedLocationLookup()
        fixture.location.requestHandler = { try await lookup.request() }
        let pending = Task { await fixture.store.useCurrentLocation() }
        await lookup.waitUntilRequested()
        #expect(fixture.store.locationSelection.isChoosingCurrentLocation)
        let manual = SavedPlace(name: "Chosen city", coordinate: destination)
        await fixture.store.chooseAndRefresh(place: manual)
        lookup.finish(fails: fails)
        #expect(await pending.value == false)
        #expect(fixture.store.savedPlace == manual)
        #expect(fixture.snapshot?.locationName == "Chosen city")
        #expect(fixture.store.locationSelection.errorMessage == nil)
        #expect(!fixture.store.locationSelection.isChoosingCurrentLocation)
    }

    @Test(arguments: [false, true])
    func failedAutomaticSwitchPreservesManualCity(completedOnboarding: Bool) async {
        let fixture = TravelFixture(completedOnboarding: completedOnboarding)
        let manual = SavedPlace(name: "Home", coordinate: origin)
        await fixture.store.chooseAndRefresh(place: manual)
        fixture.location.result = .failure(LocationError.denied)
        #expect(await fixture.store.useCurrentLocation() == false)
        #expect(fixture.store.savedPlace == manual)
        #expect(fixture.preferences.savedPlace == manual)
        #expect(!fixture.location.monitoringEnabled)
        #expect(fixture.store.locationSelection.errorMessage != nil)
        if completedOnboarding { #expect(fixture.snapshot?.locationName == "Home") }
    }

    @Test(arguments: [CLAuthorizationStatus.denied, .restricted, .authorizedWhenInUse, .authorizedAlways])
    func locationGuidanceDistinguishesBlockedAccess(status: CLAuthorizationStatus) {
        let fixture = TravelFixture()
        fixture.location.onAuthorizationChange?(status)
        #expect(fixture.store.locationAccessBlocked == (status == .denied || status == .restricted))
        #expect(fixture.store.needsAlwaysLocationNotice == (status == .authorizedWhenInUse))
    }

    @Test
    func activationChecksLocationEvenWithFreshWeather() async {
        let fixture = TravelFixture()
        await fixture.store.refresh()
        fixture.location.result = .success(destination)
        let result = await fixture.store.refreshOnActivation()
        #expect(result == .succeeded)
        #expect(fixture.location.requestLocationCount == 2)
        #expect(fixture.snapshot?.coordinate == destination)
    }

    @Test
    func smallMovementSkipsWeatherButRetainsLatestLocation() async {
        let fixture = TravelFixture()
        await fixture.store.refresh()
        let nearby = Coordinate(latitude: origin.latitude + 0.001, longitude: origin.longitude)
        let result = await fixture.store.refreshForLocation(nearby)
        #expect(result == .skipped)
        #expect(fixture.snapshot?.coordinate == origin)
        #expect(fixture.preferences.lastKnownCurrentLocation?.coordinate == nearby)
        #expect(fixture.weather.fetchCount == 1)
    }

    @Test
    func movementPublishesWeatherWidgetsAndNotificationsWithoutRequestingLocationOrReview() async {
        let fixture = TravelFixture()
        fixture.location.statusOverride = .authorizedAlways
        fixture.location.onAuthorizationChange?(.authorizedAlways)
        await fixture.store.refreshForLocation(destination)
        #expect(fixture.location.requestLocationCount == 0)
        #expect(fixture.snapshot?.coordinate == destination)
        #expect(fixture.widgets.publishedLocationNames == ["Travel city"])
        #expect(fixture.notifications.names == ["Travel city"])
        #expect(fixture.preferences.reviewSignificantEventCount == 0)
    }

    @Test
    func manualCityStopsMonitoringAndIgnoresMovement() async {
        let fixture = TravelFixture()
        fixture.store.setForeground(true)
        #expect(fixture.location.monitoringEnabled)
        let manual = SavedPlace(name: "Home", coordinate: origin)
        await fixture.store.chooseAndRefresh(place: manual)
        #expect(!fixture.location.monitoringEnabled)
        #expect(!fixture.store.needsAlwaysLocationNotice)
        #expect(await fixture.store.refreshForLocation(destination) == .skipped)
        #expect(fixture.snapshot?.coordinate == origin)
        #expect(fixture.location.requestLocationCount == 0)
    }

    @Test
    func permissionExplanationAppearsOnceAndNoticeTracksAccess() async {
        let fixture = TravelFixture()
        await fixture.store.refresh()
        fixture.store.setForeground(true)
        #expect(fixture.store.shouldOfferBackgroundLocationExplanation)
        #expect(fixture.store.needsAlwaysLocationNotice)
        fixture.store.dismissBackgroundLocationExplanation(requestAlways: true)
        #expect(fixture.location.alwaysRequests == 1)
        fixture.store.setForeground(false)
        fixture.store.setForeground(true)
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
        fixture.location.statusOverride = .authorizedAlways
        fixture.location.onAuthorizationChange?(.authorizedAlways)
        #expect(!fixture.store.needsAlwaysLocationNotice)
        fixture.location.statusOverride = .denied
        fixture.location.onAuthorizationChange?(.denied)
        #expect(!fixture.store.needsAlwaysLocationNotice)
        #expect(fixture.store.locationAccessBlocked)
        #expect(await fixture.store.refreshForLocation(destination) == .skipped)
    }

    @Test
    func newUserSeesExplanationOnNextVisitNotAfterOnboarding() async {
        let fixture = TravelFixture(completedOnboarding: false)
        fixture.store.setForeground(true)
        await fixture.store.completeOnboarding()
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
        #expect(!fixture.preferences.hasExplainedBackgroundLocation)
        // Active callbacks from permission sheets aren't a new visit.
        await fixture.store.refreshOnActivation()
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
        fixture.store.setForeground(false)
        await fixture.store.refreshOnActivation()
        #expect(fixture.store.shouldOfferBackgroundLocationExplanation)
    }

    @Test
    func cachedUpgradeRemainsEligibleUntilUserResponds() {
        let fixture = TravelFixture(cachedSnapshot: .preview)
        #expect(fixture.snapshot != nil)
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
        fixture.store.setForeground(true)
        #expect(fixture.store.shouldOfferBackgroundLocationExplanation)
        #expect(fixture.weather.fetchCount == 0)
        #expect(!fixture.preferences.hasExplainedBackgroundLocation)
        fixture.store.setForeground(false)
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
        fixture.store.setForeground(true)
        #expect(fixture.store.shouldOfferBackgroundLocationExplanation)
        fixture.store.dismissBackgroundLocationExplanation(requestAlways: false)
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
    }

    @Test
    func existingUserWaitsForDashboardBeforeExplanation() async {
        let fixture = TravelFixture()
        fixture.weather.suspendNext = true
        let activation = Task { await fixture.store.refreshOnActivation() }
        await fixture.weather.waitForSuspension()
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
        fixture.weather.resume()
        _ = await activation.value
        #expect(fixture.store.shouldOfferBackgroundLocationExplanation)
    }

    @Test
    func failedInitialLoadDoesNotShowExplanation() async {
        let fixture = TravelFixture()
        fixture.weather.fails = true
        await fixture.store.refreshOnActivation()
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
        #expect(!fixture.preferences.hasExplainedBackgroundLocation)
    }

    @Test
    func decliningAlwaysKeepsForegroundLocationWorking() async {
        let fixture = TravelFixture()
        fixture.store.setForeground(true)
        fixture.store.dismissBackgroundLocationExplanation(requestAlways: false)
        #expect(fixture.location.alwaysRequests == 0)
        #expect(fixture.location.monitoringEnabled)
        #expect(await fixture.store.refreshOnActivation() == .succeeded)
    }

    @Test
    func launchRestoresMonitoringWithoutForegroundPermissionPrompt() {
        let fixture = TravelFixture()
        fixture.location.statusOverride = .authorizedAlways
        fixture.store.synchronizeLocationMonitoring()
        #expect(fixture.location.monitoringEnabled)
        #expect(!fixture.location.monitoringForeground)
        #expect(!fixture.store.shouldOfferBackgroundLocationExplanation)
        #expect(fixture.location.requestLocationCount == 0)
    }

    @Test
    func newestMovementSurvivesAnInFlightFetch() async {
        let fixture = TravelFixture()
        fixture.weather.suspendNext = true
        let initial = Task { await fixture.store.refreshForLocation(origin) }
        await fixture.weather.waitForSuspension()
        await fixture.store.refreshForLocation(Coordinate(latitude: 39.8, longitude: -75.3))
        await fixture.store.refreshForLocation(destination)
        fixture.weather.resume()
        _ = await initial.value
        #expect(fixture.weather.coordinates == [origin, destination])
        #expect(fixture.snapshot?.coordinate == destination)
    }

    @Test
    func cityChangeDiscardsOldWeatherAndRefreshesSelectedCity() async {
        let fixture = TravelFixture()
        fixture.weather.suspendNext = true
        let initial = Task { await fixture.store.refreshForLocation(origin) }
        await fixture.weather.waitForSuspension()
        await fixture.store.chooseAndRefresh(place: SavedPlace(name: "Selected city", coordinate: destination))
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
        let initial = Task { await fixture.store.refreshForLocation(origin) }
        await fixture.weather.waitForSuspension()
        fixture.location.statusOverride = .denied
        fixture.location.onAuthorizationChange?(.denied)
        fixture.weather.resume()
        _ = await initial.value
        #expect(fixture.widgets.publishedLocationNames.isEmpty)
        #expect(fixture.notifications.names.isEmpty)
        guard case .failed = fixture.store.loadState else {
            Issue.record("Revoked permission must not leave an invalidated request loading")
            return
        }
    }

    @Test
    func failedTravelRefreshPreservesWeatherAndRetriesAtLatestLocation() async {
        let fixture = TravelFixture()
        await fixture.store.refreshForLocation(origin)
        fixture.weather.fails = true
        #expect(await fixture.store.refreshForLocation(destination) == .failed)
        #expect(fixture.snapshot?.coordinate == origin)
        #expect(fixture.preferences.lastKnownCurrentLocation?.coordinate == destination)
        fixture.weather.fails = false
        #expect(await fixture.store.refreshForBackground() == .succeeded)
        #expect(fixture.snapshot?.coordinate == destination)
        #expect(fixture.location.requestLocationCount == 0)
    }
}

private final class TravelFixture {
    let preferences = InMemoryUserPreferenceStore()
    let location = LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398)), placename: "Travel city")
    let weather = TravelWeatherProvider()
    let widgets = WidgetSnapshotPublisherSpy()
    let notifications = TravelNotificationSpy()
    let store: AppStore

    init(completedOnboarding: Bool = true, cachedSnapshot: WeatherSnapshot? = nil) {
        preferences.hasCompletedOnboarding = completedOnboarding
        let cache = WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "travel-\(UUID()).json"))
        if let cachedSnapshot { cache.save(cachedSnapshot) }
        store = AppStore(weather: weather, location: location, places: PlaceSearchStub(),
                         notifications: notifications,
                         cache: cache,
                         widgetPublisher: widgets, userPreferences: preferences,
                         appReviewManager: AppReviewManager(userPreferences: preferences))
    }

    var snapshot: WeatherSnapshot? {
        if case .loaded(let snapshot, _) = store.loadState { return snapshot }
        return nil
    }
}

@MainActor
private final class TravelWeatherProvider: WeatherProviding {
    var coordinates: [Coordinate] = []
    var fetchCount: Int { coordinates.count }
    var suspendNext = false
    var fails = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var suspensionWaiter: CheckedContinuation<Void, Never>?

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        coordinates.append(coordinate)
        if suspendNext {
            suspendNext = false
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                suspensionWaiter?.resume()
                suspensionWaiter = nil
            }
        }
        if fails { throw WeatherProviderError.unavailable }
        let base = WeatherSnapshot.preview
        return WeatherSnapshot(locationName: locationName, coordinate: coordinate, fetchedAt: .now,
                               current: base.current, hourly: base.hourly)
    }

    func waitForSuspension() async {
        if continuation != nil { return }
        await withCheckedContinuation { suspensionWaiter = $0 }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private final class TravelNotificationSpy: NotificationScheduling {
    var names: [String] = []
    var status: UNAuthorizationStatus = .authorized
    var requestedStatus: UNAuthorizationStatus = .authorized
    var requestCount = 0
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        status = requestedStatus
        return status == .authorized
    }
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {
        names.append(locationName)
    }
}


@Suite
struct AlertPermissionTests {
    @Test
    func activationReadsPermissionEvenBeforeOnboarding() async {
        let fixture = TravelFixture()
        fixture.preferences.hasCompletedOnboarding = false
        #expect(await fixture.store.refreshOnActivation() == .skipped)
        #expect(fixture.store.notificationStatus == .authorized)
        #expect(fixture.notifications.requestCount == 0)
        fixture.notifications.status = .denied
        await fixture.store.refreshOnActivation()
        #expect(fixture.store.notificationStatus == .denied)
    }

    @Test
    func enablingAlertsRequestsPermissionAndSchedulesLoadedForecast() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .notDetermined
        await fixture.store.usePreviewWeather()
        await fixture.store.setAlertsEnabled(true)
        #expect(fixture.store.preferences.alertsEnabled)
        #expect(fixture.notifications.requestCount == 1)
        #expect(fixture.store.notificationStatus == .authorized)
        #expect(!fixture.store.isRequestingNotificationPermission)
        #expect(!fixture.notifications.names.isEmpty)
    }

    @Test(arguments: [UNAuthorizationStatus.authorized, .denied, .provisional])
    func existingPermissionDoesNotPromptAgain(status: UNAuthorizationStatus) async {
        let fixture = TravelFixture()
        fixture.notifications.status = status
        await fixture.store.setAlertsEnabled(true)
        #expect(fixture.notifications.requestCount == 0)
        #expect(fixture.store.notificationStatus == status)
        #expect(fixture.store.alertsEffectivelyEnabled == (status != .denied))
        #expect(fixture.store.preferences.alertsEnabled == (status != .denied))
    }

    @Test
    func deniedRequestLeavesAlertsOff() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .notDetermined
        fixture.notifications.requestedStatus = .denied
        #expect(await fixture.store.setAlertsEnabled(true) == false)
        #expect(!fixture.store.preferences.alertsEnabled)
        #expect(!fixture.store.alertsEffectivelyEnabled)
    }

    @Test
    func grantingPermissionInSettingsCompletesPendingEnable() async {
        let fixture = TravelFixture()
        fixture.preferences.hasCompletedOnboarding = false
        fixture.notifications.status = .denied
        await fixture.store.setAlertsEnabled(true)
        #expect(!fixture.store.alertsEffectivelyEnabled)
        fixture.store.enableAlertsWhenPermissionGranted()
        #expect(fixture.store.preferences.alertsEnabled)
        #expect(!fixture.store.alertsEffectivelyEnabled)
        await fixture.store.refreshOnActivation()
        #expect(!fixture.store.alertsEffectivelyEnabled)
        fixture.notifications.status = .authorized
        await fixture.store.refreshOnActivation()
        #expect(fixture.store.alertsEffectivelyEnabled)
        #expect(fixture.notifications.requestCount == 0)
    }

    @Test
    func cancellingPermissionAlertDoesNotEnableAfterExternalPermissionChange() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .denied
        await fixture.store.setAlertsEnabled(true)
        // Cancel does not save a pending enable request.
        fixture.notifications.status = .authorized
        await fixture.store.refreshNotificationPermission()
        #expect(!fixture.store.alertsEffectivelyEnabled)
        #expect(!fixture.store.preferences.alertsEnabled)
    }

    @Test
    func revokingPermissionTurnsEffectiveSwitchOff() async {
        let fixture = TravelFixture()
        await fixture.store.setAlertsEnabled(true)
        #expect(fixture.store.alertsEffectivelyEnabled)
        fixture.notifications.status = .denied
        await fixture.store.refreshNotificationPermission()
        #expect(!fixture.store.alertsEffectivelyEnabled)
        fixture.notifications.status = .authorized
        await fixture.store.refreshNotificationPermission()
        #expect(fixture.store.alertsEffectivelyEnabled)
        await fixture.store.setAlertsEnabled(false)
        #expect(!fixture.store.alertsEffectivelyEnabled)
    }

    @Test
    func disablingAlertsDoesNotRequestPermission() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .notDetermined
        await fixture.store.setAlertsEnabled(false)
        #expect(!fixture.store.preferences.alertsEnabled)
        #expect(fixture.notifications.requestCount == 0)
    }

    @Test
    func declinedRequestUpdatesLabelAndDoesNotRepeatPrompt() async {
        let fixture = TravelFixture()
        fixture.notifications.status = .notDetermined
        fixture.notifications.requestedStatus = .denied
        await fixture.store.requestNotificationPermission()
        #expect(fixture.store.notificationStatus == .denied)
        await fixture.store.requestNotificationPermission()
        #expect(fixture.notifications.requestCount == 1)
    }
}

@MainActor
private final class SuspendedLocationLookup {
    private var continuation: CheckedContinuation<Coordinate, any Error>?
    private var waiter: CheckedContinuation<Void, Never>?

    func request() async throws -> Coordinate {
        try await withCheckedThrowingContinuation {
            continuation = $0
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilRequested() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func finish(fails: Bool) {
        if fails { continuation?.resume(throwing: LocationError.unavailable) }
        else { continuation?.resume(returning: .init(latitude: 41, longitude: -82)) }
        continuation = nil
    }
}
