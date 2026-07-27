import Foundation
import Testing
@testable import OpenAir

@Suite
struct UserPreferenceStoreTests {
    @Test
    func defaultValues() async {
        let fixture = UserPreferenceStoreFixture()
        let store = fixture.makeStore(locale: Locale(identifier: "en_US"))

        #expect(!store.hasCompletedOnboarding)
        #expect(store.savedPlace == nil)
        #expect(store.lastKnownCurrentLocation == nil)
        #expect(store.preferences == .default(for: Locale(identifier: "en_US")))
        #expect(store.reviewSignificantEventCount == 0)
        #expect(store.lastReviewRequestAttemptAt == nil)
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
        preferences.temperatureEvaluationSource = .feelsLike
        preferences.maximumWindMPH = 12
        preferences.maximumGustMPH = 38
        fixture.makeStore().preferences = preferences

        let restored = fixture.makeStore()

        #expect(restored.preferences == preferences)
    }

    @Test
    func appReviewStatePersists() async throws {
        let fixture = UserPreferenceStoreFixture()
        let requestDate = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 17)))
        let store = fixture.makeStore()
        store.reviewSignificantEventCount = 2
        store.lastReviewRequestAttemptAt = requestDate

        let restored = fixture.makeStore()

        #expect(restored.reviewSignificantEventCount == 2)
        #expect(restored.lastReviewRequestAttemptAt == requestDate)
    }

    @Test
    func savedPreferencesWithoutNewerFieldsReceiveDefaults() async throws {
        let preferences = LegacyComfortPreferences(
            idealMinimumFahrenheit: 50,
            idealMaximumFahrenheit: 76,
            maximumDewPointFahrenheit: 61,
            maximumRainChance: 0.4,
            maximumWindMPH: 14,
            alertsEnabled: false,
            temperatureUnit: .celsius
        )
        let data = try JSONEncoder().encode(preferences)
        let fixture = UserPreferenceStoreFixture()
        fixture.defaults.set(data, forKey: "comfortPreferences")

        let restored = fixture.makeStore().preferences

        #expect(restored.idealMinimumFahrenheit == 50)
        #expect(restored.idealMaximumFahrenheit == 76)
        #expect(restored.maximumDewPointFahrenheit == 61)
        #expect(restored.maximumRainChance == 0.4)
        #expect(restored.maximumWindMPH == 14)
        #expect(restored.maximumGustMPH == .defaultMaximumGustMPH)
        #expect(!restored.alertsEnabled)
        #expect(restored.temperatureUnit == .celsius)
        #expect(restored.temperatureEvaluationSource == .feelsLike)
    }
}
private final class UserPreferenceStoreFixture {
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: "UserPreferenceStoreTests.\(UUID().uuidString)")!
    }

    func makeStore(locale: Locale = Locale(identifier: "en_US")) -> UserPreferenceStore {
        UserPreferenceStore(userDefaults: defaults, locale: locale)
    }
}

private struct LegacyComfortPreferences: Codable {
    var idealMinimumFahrenheit: Double
    var idealMaximumFahrenheit: Double
    var maximumDewPointFahrenheit: Double
    var maximumRainChance: Double
    var maximumWindMPH: Double
    var alertsEnabled: Bool
    var temperatureUnit: TemperatureUnit
}
