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

    func testOldDefaultRainThresholdMigratesToFiftyPercent() throws {
        var oldPreferences = ComfortPreferences.default
        oldPreferences.maximumRainChance = 0.20
        defaults.set(try JSONEncoder().encode(oldPreferences), forKey: "comfortPreferences")

        let store = makeStore()

        XCTAssertEqual(store.preferences.maximumRainChance, 0.50)
    }

    func testCustomizedRainThresholdIsNotMigrated() throws {
        var customizedPreferences = ComfortPreferences.default
        customizedPreferences.maximumRainChance = 0.35
        defaults.set(try JSONEncoder().encode(customizedPreferences), forKey: "comfortPreferences")

        let store = makeStore()

        XCTAssertEqual(store.preferences.maximumRainChance, 0.35)
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

    private func makeStore(
        weather: any WeatherProviding = PreviewWeatherClient(),
        location: any LocationProviding = LocationStub(result: .success(.init(latitude: 0, longitude: 0)))
    ) -> AppStore {
        AppStore(
            weather: weather,
            location: location,
            places: PlaceSearchStub(),
            evaluator: RecommendationEngine(),
            notifications: NotificationStub(),
            cache: WeatherCache(url: cacheURL),
            defaults: defaults
        )
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

@MainActor
private struct NotificationStub: NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {}
}
