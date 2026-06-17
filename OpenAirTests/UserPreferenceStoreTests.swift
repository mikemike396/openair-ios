import Foundation
import Testing
@testable import OpenAir

@Suite
@MainActor
struct UserPreferenceStoreTests {
    @Test
    func defaultValues() async {
        let fixture = UserPreferenceStoreFixture()
        let store = fixture.makeStore(locale: Locale(identifier: "en_US"))

        #expect(!store.hasCompletedOnboarding)
        #expect(store.savedPlace == nil)
        #expect(store.lastKnownCurrentLocation == nil)
        #expect(store.preferences == .default(for: Locale(identifier: "en_US")))
    }

    @Test
    func onboardingPersists() async {
        let fixture = UserPreferenceStoreFixture()
        fixture.makeStore().hasCompletedOnboarding = true

        let restored = fixture.makeStore()

        #expect(restored.hasCompletedOnboarding)
    }

    @Test
    func savedPlacePersists() async {
        let fixture = UserPreferenceStoreFixture()
        let place = SavedPlace(
            name: "Wilmington, DE",
            coordinate: .init(latitude: 39.7, longitude: -75.5)
        )
        fixture.makeStore().savedPlace = place

        let restored = fixture.makeStore()

        #expect(restored.savedPlace == place)
    }

    @Test
    func lastKnownCurrentLocationPersists() async {
        let fixture = UserPreferenceStoreFixture()
        let place = SavedPlace(
            name: "Wilmington, DE",
            coordinate: .init(latitude: 39.7, longitude: -75.5)
        )
        fixture.makeStore().lastKnownCurrentLocation = place

        let restored = fixture.makeStore()

        #expect(restored.lastKnownCurrentLocation == place)
    }

    @Test
    func preferencesPersist() async {
        let fixture = UserPreferenceStoreFixture()
        var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
        preferences.temperatureUnit = .celsius
        preferences.maximumWindMPH = 12
        fixture.makeStore().preferences = preferences

        let restored = fixture.makeStore()

        #expect(restored.preferences == preferences)
    }
}

@MainActor
private final class UserPreferenceStoreFixture {
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: "UserPreferenceStoreTests.\(UUID().uuidString)")!
    }

    func makeStore(locale: Locale = Locale(identifier: "en_US")) -> UserPreferenceStore {
        UserPreferenceStore(userDefaults: defaults, locale: locale)
    }
}
