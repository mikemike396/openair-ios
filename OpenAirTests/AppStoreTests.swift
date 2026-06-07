import CoreLocation
import UserNotifications
import XCTest
@testable import OpenAir

@MainActor
final class AppStoreTests: XCTestCase {
    private let defaults = UserDefaults(suiteName: "AppStoreTests.\(UUID().uuidString)")!
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
        guard case .loaded(let snapshot, _, _) = store.loadState else {
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

        guard case .loaded(let snapshot, _, _) = store.loadState else {
            return XCTFail("Expected loaded dashboard state")
        }
        XCTAssertEqual(snapshot.locationName, "Wilmington, DE")
    }

    func testCurrentLocationFallsBackWhenPlacenameIsUnavailable() async {
        let store = makeStore()

        await store.completeOnboarding()

        guard case .loaded(let snapshot, _, _) = store.loadState else {
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

        guard case .loaded(let manualSnapshot, _, _) = store.loadState else {
            return XCTFail("Expected loaded manual city")
        }
        XCTAssertEqual(manualSnapshot.locationName, "Philadelphia, PA")

        let switchedToCurrentLocation = await store.useCurrentLocation()
        XCTAssertTrue(switchedToCurrentLocation)

        guard case .loaded(let currentSnapshot, _, _) = store.loadState else {
            return XCTFail("Expected loaded current location")
        }
        XCTAssertEqual(currentSnapshot.locationName, "Wilmington, DE")
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

        guard case .loaded(let initialSnapshot, _, _) = store.loadState else {
            return XCTFail("Expected loaded initial city")
        }
        XCTAssertEqual(initialSnapshot.locationName, "Philadelphia, PA")

        await store.chooseAndRefresh(place: newPlace)

        guard case .loaded(let refreshedSnapshot, _, _) = store.loadState else {
            return XCTFail("Expected refreshed manual city")
        }
        XCTAssertEqual(refreshedSnapshot.locationName, "Wilmington, DE")
    }

    func testPreferencesPersist() {
        let store = makeStore()
        var preferences = store.preferences
        preferences.temperatureUnit = .celsius
        preferences.maximumWindMPH = 12
        store.preferences = preferences

        let restored = makeStore()

        XCTAssertEqual(restored.preferences.temperatureUnit, .celsius)
        XCTAssertEqual(restored.preferences.maximumWindMPH, 12)
    }

    func testFirstLaunchDefaultsTemperatureUnitFromMetricLocale() {
        let store = makeStore(locale: Locale(identifier: "ja_JP"))

        XCTAssertEqual(store.preferences.temperatureUnit, .celsius)
    }

    func testFirstLaunchDefaultsTemperatureUnitFromUSLocale() {
        let store = makeStore(locale: Locale(identifier: "en_US"))

        XCTAssertEqual(store.preferences.temperatureUnit, .fahrenheit)
    }

    func testSavedTemperatureUnitOverridesLocaleDefault() {
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
        let cached = Self.snapshot(fetchedAt: now.addingTimeInterval(-60 * 16))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.refreshIfNeeded(now: now) }
        await weather.waitUntilFetchStarts()

        XCTAssertTrue(store.isRefreshing)
        guard case .loaded(let snapshot, _, _) = store.loadState else {
            refreshTask.cancel()
            return XCTFail("Expected old forecast to remain visible during foreground refresh")
        }
        XCTAssertEqual(snapshot, cached)

        await weather.resume(returning: Self.snapshot(fetchedAt: now))
        await refreshTask.value
        XCTAssertFalse(store.isRefreshing)
    }

    func testCachedWeatherIsLoadedImmediatelyAfterInitialization() {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()

        let store = makeStore()

        guard case .loaded(let snapshot, _, let isOffline) = store.loadState else {
            return XCTFail("Expected cached dashboard state")
        }
        XCTAssertEqual(snapshot, cached)
        XCTAssertFalse(isOffline)
    }

    func testStartRefreshesFreshCachedWeather() async {
        let cached = Self.snapshot(fetchedAt: Date())
        let refreshed = Self.snapshot(fetchedAt: Date().addingTimeInterval(60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = WeatherSpy(snapshots: [refreshed])
        let store = makeStore(weather: weather)

        await store.start()

        let fetchCount = await weather.fetchCount
        XCTAssertEqual(fetchCount, 1)
        guard case .loaded(let snapshot, _, let isOffline) = store.loadState else {
            return XCTFail("Expected refreshed dashboard state")
        }
        XCTAssertEqual(snapshot.fetchedAt, refreshed.fetchedAt)
        XCTAssertFalse(isOffline)
    }

    func testStartKeepsCachedWeatherVisibleWhileRefreshIsPending() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let weather = SuspendedWeatherProvider()
        let store = makeStore(weather: weather)

        let refreshTask = Task { await store.start() }
        await weather.waitUntilFetchStarts()

        XCTAssertTrue(store.isRefreshing)
        guard case .loaded(let snapshot, _, _) = store.loadState else {
            refreshTask.cancel()
            return XCTFail("Expected cached dashboard state during refresh")
        }
        XCTAssertEqual(snapshot, cached)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        await refreshTask.value
        XCTAssertFalse(store.isRefreshing)
    }

    func testStartFailurePreservesCachedWeatherAsOffline() async {
        let cached = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(cached)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        await store.start()

        XCTAssertFalse(store.isRefreshing)
        guard case .loaded(let snapshot, _, let isOffline) = store.loadState else {
            return XCTFail("Expected cached dashboard state")
        }
        XCTAssertEqual(snapshot, cached)
        XCTAssertTrue(isOffline)
    }

    func testPreservingRefreshKeepsLoadedWeatherVisibleWhilePending() async {
        let current = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        let weather = SuspendedWeatherProvider()
        WeatherCache(url: cacheURL).save(current)
        markOnboardingCompleted()
        let restoredStore = makeStore(weather: weather)

        let refreshTask = Task { await restoredStore.refreshPreservingLoadedState() }
        await weather.waitUntilFetchStarts()

        XCTAssertTrue(restoredStore.isRefreshing)
        guard case .loaded(let snapshot, _, _) = restoredStore.loadState else {
            refreshTask.cancel()
            return XCTFail("Expected loaded weather during preserving refresh")
        }
        XCTAssertEqual(snapshot, current)

        await weather.resume(returning: Self.snapshot(fetchedAt: Date()))
        await refreshTask.value
        XCTAssertFalse(restoredStore.isRefreshing)
    }

    func testPreservingRefreshFailureKeepsLoadedWeatherOffline() async {
        let current = Self.snapshot(fetchedAt: Date().addingTimeInterval(-60))
        WeatherCache(url: cacheURL).save(current)
        markOnboardingCompleted()
        let store = makeStore(weather: FailingWeatherProvider())

        await store.refreshPreservingLoadedState()

        guard case .loaded(let snapshot, _, let isOffline) = store.loadState else {
            return XCTFail("Expected loaded weather after failed preserving refresh")
        }
        XCTAssertEqual(snapshot, current)
        XCTAssertTrue(isOffline)
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
        await refreshTask.value

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
        await startTask.value
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
            userPreferences: makeUserPreferences(locale: locale)
        )
    }

    private func makeUserPreferences(locale: Locale = Locale(identifier: "en_US")) -> UserPreferenceStore {
        UserPreferenceStore(userDefaults: defaults, locale: locale)
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
private final class LocationStub: LocationProviding {
    let result: Result<Coordinate, any Error>
    let placename: String?
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
    func requestLocation() async throws -> Coordinate { try result.get() }
    func placename(for coordinate: Coordinate) async -> String? { placename }
}

private struct PlaceSearchStub: PlaceSearching {
    func search(query: String) async throws -> [SavedPlace] { [] }
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
        return WeatherSnapshot(
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

private actor SuspendedWeatherProvider: WeatherProviding {
    private var continuation: CheckedContinuation<WeatherSnapshot, any Error>?
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private(set) var fetchCount = 0

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        fetchCount += 1
        fetchStartedContinuation?.resume()
        fetchStartedContinuation = nil
        let snapshot = try await withCheckedThrowingContinuation { continuation = $0 }
        return WeatherSnapshot(
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
