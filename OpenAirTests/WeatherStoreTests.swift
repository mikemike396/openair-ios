import CoreLocation
import Testing
import UserNotifications
@testable import OpenAir

@Suite
struct WeatherStoreTests {
    private let userPreferences = InMemoryUserPreferenceStore()
    private let cacheURL = FileManager.default.temporaryDirectory
        .appending(path: "openair-tests-\(UUID().uuidString).json")

    @Test
    func standaloneStoreKeepsPendingMovementAheadOfScheduledRefresh() async {
        let origin = Coordinate(latitude: 39.7, longitude: -75.5)
        let destination = Coordinate(latitude: 40, longitude: -75)
        let provider = TravelWeatherProvider()
        provider.suspendNext = true
        let location = LocationStub(result: .success(origin))
        let weather = WeatherStore(
            requests: WeatherRequestCoordinator(weather: provider, location: location, preferences: userPreferences),
            evaluator: RecommendationEngine(), cache: WeatherCache(url: cacheURL),
            widgets: DisabledWidgetSnapshotPublisher(), preferences: userPreferences
        )
        let initial = Task { await weather.refresh(source: .deliveredLocation(origin)) }
        await provider.waitForSuspension()

        #expect(await weather.refresh(source: .deliveredLocation(destination)) == .skipped)
        #expect(await weather.refresh(source: .savedLocation) == .skipped)
        provider.resume()

        #expect(await initial.value == .succeeded)
        #expect(provider.coordinates == [origin, destination])
        #expect(weather.refreshState == .idle)
        #expect(location.requestLocationCount == 0)
        guard case .loaded(let snapshot, _) = weather.loadState else {
            Issue.record("Expected latest movement forecast")
            return
        }
        #expect(snapshot.coordinate == destination)
    }

    @Test
    func testManualCityCompletesOnboardingAndLoadsWeather() async {
        let place = SavedPlace(
            name: "Wilmington, DE",
            coordinate: .init(latitude: 39.7, longitude: -75.5)
        )
        let store = makeStore(location: LocationStub(result: .failure(LocationError.denied)))
        store.locationStore.choose(place: place)

        await store.coordinator.completeOnboarding()

        #expect(store.userPreferences.hasCompletedOnboarding)
        guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
            Issue.record("Expected loaded dashboard state")
            return
        }
        #expect(snapshot.locationName == place.name)

        let restored = makeStore()
        #expect(restored.userPreferences.hasCompletedOnboarding)
        #expect(restored.locationStore.savedPlace == place)
    }

    @Test
    func testDeniedCurrentLocationProducesFailureState() async {
        let store = makeStore(location: LocationStub(result: .failure(LocationError.denied)))

        await store.coordinator.completeOnboarding()

        guard case .failed(let message, _) = store.weatherStore.loadState else {
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

        await store.coordinator.completeOnboarding()

        guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
            Issue.record("Expected loaded dashboard state")
            return
        }
        #expect(snapshot.locationName == "Wilmington, DE")
    }

    @Test
    func testCurrentLocationFallsBackWhenPlacenameIsUnavailable() async {
        let store = makeStore()

        await store.coordinator.completeOnboarding()

        guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
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
        store.locationStore.choose(place: place)

        await store.coordinator.completeOnboarding()

        guard case .loaded(let manualSnapshot, _) = store.weatherStore.loadState else {
            Issue.record("Expected loaded manual city")
            return
        }
        #expect(manualSnapshot.locationName == "Philadelphia, PA")

        let switchedToCurrentLocation = await store.coordinator.useCurrentLocation()
        #expect(switchedToCurrentLocation)

        guard case .loaded(let currentSnapshot, _) = store.weatherStore.loadState else {
            Issue.record("Expected loaded current location")
            return
        }
        #expect(currentSnapshot.locationName == "Wilmington, DE")
        #expect(store.locationStore.lastKnownCurrentLocation?.name == "Wilmington, DE")
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
        store.locationStore.choose(place: initialPlace)

        await store.coordinator.completeOnboarding()

        guard case .loaded(let initialSnapshot, _) = store.weatherStore.loadState else {
            Issue.record("Expected loaded initial city")
            return
        }
        #expect(initialSnapshot.locationName == "Philadelphia, PA")

        await store.coordinator.chooseAndRefresh(place: newPlace)

        guard case .loaded(let refreshedSnapshot, _) = store.weatherStore.loadState else {
            Issue.record("Expected refreshed manual city")
            return
        }
        #expect(refreshedSnapshot.locationName == "Wilmington, DE")
    }

    @Test
    func testPreferencesPersist() async {
        let store = makeStore()
        var preferences = store.userPreferences.preferences
        preferences.temperatureUnit = .celsius
        preferences.maximumWindMPH = 12
        store.coordinator.updatePreferences(preferences)

        let restored = makeStore()

        #expect(restored.userPreferences.preferences.temperatureUnit == .celsius)
        #expect(restored.userPreferences.preferences.maximumWindMPH == 12)
    }

    @Test
    func testFirstLaunchDefaultsTemperatureUnitFromMetricLocale() async {
        let store = makeStore(locale: Locale(identifier: "ja_JP"))

        #expect(store.userPreferences.preferences.temperatureUnit == .celsius)
    }

    @Test
    func testFirstLaunchDefaultsTemperatureUnitFromUSLocale() async {
        let store = makeStore(locale: Locale(identifier: "en_US"))

        #expect(store.userPreferences.preferences.temperatureUnit == .fahrenheit)
    }

    @Test
    func testSavedTemperatureUnitOverridesLocaleDefault() async {
        var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
        preferences.temperatureUnit = .fahrenheit
        makeUserPreferences(locale: Locale(identifier: "en_US")).preferences = preferences

        let store = makeStore(locale: Locale(identifier: "ja_JP"))

        #expect(store.userPreferences.preferences.temperatureUnit == .fahrenheit)
    }

    @Test
    func testForegroundRefreshSkipsFreshForecast() async {
        let now = Date()
        let weather = WeatherSpy(snapshots: [Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 14))])
        let store = makeStore(weather: weather)
        store.userPreferences.hasCompletedOnboarding = true

        await store.coordinator.refresh()
        await store.coordinator.refreshIfNeeded(now: now)

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
        store.userPreferences.hasCompletedOnboarding = true

        await store.coordinator.refresh()
        await store.coordinator.refreshIfNeeded(now: now)

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

        let refreshTask = Task { await store.coordinator.refreshIfNeeded(now: now) }
        await weather.waitUntilFetchStarts()

        #expect(store.weatherStore.refreshState == .refreshing)
        guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
            refreshTask.cancel()
            Issue.record("Expected old forecast to remain visible during foreground refresh")
            return
        }
        #expect(snapshot == cached)
        #expect(!store.weatherStore.shouldShowStaleBanner(for: snapshot, now: now))

        await weather.resume(returning: Self.snapshot(fetchedAt: now))
        _ = await refreshTask.value
        #expect(store.weatherStore.refreshState == .idle)
    }

    @Test
    func testFailedRefreshShowsBannerForStaleCachedWeather() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        let result = await store.coordinator.refresh(keepsLoadedState: true)

        #expect(result == .failed)
        #expect(store.weatherStore.refreshState == .failed)
        #expect(store.weatherStore.shouldShowStaleBanner(for: cached, now: now))
    }

    @Test
    func testFailedRefreshDoesNotShowBannerForFreshCachedWeather() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        let result = await store.coordinator.refresh(keepsLoadedState: true)

        #expect(result == .failed)
        #expect(!store.weatherStore.shouldShowStaleBanner(for: cached, now: now))
    }

    @Test
    func testSuccessfulRefreshClearsFailedRefreshBanner() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        let refreshed = Self.snapshot(fetchedAt: now)
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingThenSucceedingWeatherProvider(snapshot: refreshed))
        _ = await store.coordinator.refresh(keepsLoadedState: true)
        #expect(store.weatherStore.shouldShowStaleBanner(for: cached, now: now))

        let result = await store.coordinator.refresh(keepsLoadedState: true)

        #expect(result == .succeeded)
        #expect(store.weatherStore.refreshState == .idle)
        #expect(!store.weatherStore.shouldShowStaleBanner(for: refreshed, now: now))
    }

    @Test
    func testRetrySuppressesFailedRefreshBannerWhilePending() async {
        let now = Date()
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 60 * 4))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = FailingThenSuspendedWeatherProvider()
        let store = makeStore(weather: weather)
        _ = await store.coordinator.refresh(keepsLoadedState: true)
        #expect(store.weatherStore.shouldShowStaleBanner(for: cached, now: now))

        let retryTask = Task { await store.coordinator.refresh(keepsLoadedState: true) }
        await weather.waitUntilSecondFetchStarts()

        #expect(store.weatherStore.refreshState == .refreshing)
        #expect(!store.weatherStore.shouldShowStaleBanner(for: cached, now: now))

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

        let result = await store.coordinator.refresh(keepsLoadedState: true)

        #expect(result == .failed)
        guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
            Issue.record("Expected cached weather to remain loaded")
            return
        }
        #expect(snapshot == cached)
    }

    @Test
    func failedFetchDoesNotAdvancePersistedRainRecovery() async {
        let rainAt = Date().addingTimeInterval(-90 * 60)
        let cached = Self.snapshot(fetchedAt: rainAt)
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        userPreferences.recommendationStabilization = RecommendationStabilizationState(
            coordinate: cached.coordinate,
            effective: .init(status: .keepClosed, reasons: [.recentRain]),
            pendingStatus: nil,
            pendingSince: nil,
            lastRainAt: rainAt,
            awaitingRainRecovery: true,
            lastObservationAt: rainAt
        )
        let store = makeStore(weather: FailingWeatherProvider())

        #expect(await store.coordinator.refresh(keepsLoadedState: true) == .failed)
        #expect(userPreferences.recommendationStabilization?.lastRainAt == rainAt)
        #expect(userPreferences.recommendationStabilization?.lastObservationAt == rainAt)
        guard case .loaded(_, let plan) = store.weatherStore.loadState else {
            Issue.record("Expected cached recommendation after failed fetch")
            return
        }
        #expect(plan.current.reasons.contains(.recentRain))
    }

    @Test
    func testCachePreservingRefreshReturnsSuccessForBackgroundCompletion() async {
        let refreshed = Self.snapshot(fetchedAt: Date())
        let store = makeStore(weather: WeatherSpy(snapshots: [refreshed]))

        let result = await store.coordinator.refresh(keepsLoadedState: true)

        #expect(result == .succeeded)
    }

    @Test
    func testCachedWeatherIsLoadedImmediatelyAfterInitialization() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()

        let store = makeStore()

        guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
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

        let result = await store.coordinator.refreshOnActivation()

        let fetchCount = await weather.fetchCount
        #expect(result == .skipped)
        #expect(fetchCount == 0)
        #expect(location.requestLocationCount == 1)
        guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
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

        let refreshTask = Task { await store.coordinator.refreshOnActivation() }
        await weather.waitUntilFetchStarts()

        #expect(store.weatherStore.refreshState == .refreshing)
        guard case .loaded(let snapshot, _) = store.weatherStore.loadState else {
            refreshTask.cancel()
            Issue.record("Expected cached dashboard state during refresh")
            return
        }
        #expect(snapshot == cached)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        _ = await refreshTask.value
        #expect(store.weatherStore.refreshState == .idle)
    }

    @Test
    func testPreservingRefreshKeepsLoadedWeatherVisibleWhilePending() async {
        let current = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        let weather = SuspendedWeatherProvider()
        WeatherCache(url: cacheURL).save(current)
        markOnboardingCompleted()
        let restoredStore = makeStore(weather: weather)

        let refreshTask = Task { await restoredStore.coordinator.refresh(keepsLoadedState: true) }
        await weather.waitUntilFetchStarts()

        #expect(restoredStore.weatherStore.refreshState == .refreshing)
        guard case .loaded(let snapshot, _) = restoredStore.weatherStore.loadState else {
            refreshTask.cancel()
            Issue.record("Expected loaded weather during preserving refresh")
            return
        }
        #expect(snapshot == current)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        _ = await refreshTask.value
        #expect(restoredStore.weatherStore.refreshState == .idle)
    }

    @Test
    func testStartWithoutCacheShowsLoadingThenFailure() async {
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.coordinator.refreshOnActivation() }
        await weather.waitUntilFetchStarts()

        guard case .loading = store.weatherStore.loadState else {
            refreshTask.cancel()
            Issue.record("Expected loading state without cached weather")
            return
        }

        await weather.resume(throwing: WeatherProviderError.unavailable)
        _ = await refreshTask.value

        guard case .failed = store.weatherStore.loadState else {
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

        let startTask = Task { await store.coordinator.refreshOnActivation() }
        await weather.waitUntilFetchStarts()
        await store.coordinator.refreshIfNeeded()

        let fetchCount = await weather.fetchCount
        #expect(fetchCount == 1)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        _ = await startTask.value
    }

    private func makeStore(
        weather: any WeatherProviding = PreviewWeatherClient(),
        location: any LocationProviding = LocationStub(result: .success(.init(latitude: 0, longitude: 0))),
        locale: Locale = Locale(identifier: "en_US")
    ) -> AppTestFixture {
        AppTestFixture(
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
