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

    private func makeStore(
        location: any LocationProviding = LocationStub(result: .success(.init(latitude: 0, longitude: 0)))
    ) -> AppStore {
        AppStore(
            weather: PreviewWeatherClient(),
            location: location,
            places: PlaceSearchStub(),
            evaluator: RecommendationEngine(),
            notifications: NotificationStub(),
            cache: WeatherCache(url: cacheURL),
            defaults: defaults
        )
    }
}

@MainActor
private final class LocationStub: LocationProviding {
    let result: Result<Coordinate, any Error>
    var authorizationStatus: CLAuthorizationStatus {
        switch result {
        case .success: .authorizedWhenInUse
        case .failure: .denied
        }
    }

    init(result: Result<Coordinate, any Error>) {
        self.result = result
    }

    func requestAuthorization() {}
    func requestLocation() async throws -> Coordinate { try result.get() }
}

private struct PlaceSearchStub: PlaceSearching {
    func search(query: String) async throws -> [SavedPlace] { [] }
}

@MainActor
private struct NotificationStub: NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {}
}
