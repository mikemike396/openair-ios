import XCTest
@testable import OpenAir

final class UserPreferenceStoreTests: XCTestCase {
    private let defaults = UserDefaults(suiteName: "UserPreferenceStoreTests.\(UUID().uuidString)")!

    func testDefaultValues() {
        let store = UserPreferenceStore(userDefaults: defaults, locale: Locale(identifier: "en_US"))

        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertNil(store.savedPlace)
        XCTAssertEqual(store.preferences, .default(for: Locale(identifier: "en_US")))
    }

    func testOnboardingPersists() {
        UserPreferenceStore(userDefaults: defaults).hasCompletedOnboarding = true

        let restored = UserPreferenceStore(userDefaults: defaults)

        XCTAssertTrue(restored.hasCompletedOnboarding)
    }

    func testSavedPlacePersists() {
        let place = SavedPlace(
            name: "Wilmington, DE",
            coordinate: .init(latitude: 39.7, longitude: -75.5)
        )
        UserPreferenceStore(userDefaults: defaults).savedPlace = place

        let restored = UserPreferenceStore(userDefaults: defaults)

        XCTAssertEqual(restored.savedPlace, place)
    }

    func testPreferencesPersist() {
        var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
        preferences.temperatureUnit = .celsius
        preferences.maximumWindMPH = 12
        UserPreferenceStore(userDefaults: defaults).preferences = preferences

        let restored = UserPreferenceStore(userDefaults: defaults)

        XCTAssertEqual(restored.preferences, preferences)
    }
}
