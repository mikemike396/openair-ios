import Foundation
import Testing
@testable import OpenAir
@Suite
struct TemperatureUnitTests {
    @Test
    func testFahrenheitDisplayRounds() {
        #expect(TemperatureUnit.fahrenheit.display(64.6) == 65)
    }

    @Test
    func testCelsiusConversionAndRounding() {
        #expect(TemperatureUnit.celsius.display(32) == 0)
        #expect(TemperatureUnit.celsius.display(68) == 20)
    }

    @Test
    func testDefaultPreferencesUseFahrenheitForUSLocale() {
        #expect(
            ComfortPreferences.default(for: Locale(identifier: "en_US")).temperatureUnit == .fahrenheit
        )
    }

    @Test
    func testDefaultPreferencesUseCelsiusForMetricLocale() {
        #expect(
            ComfortPreferences.default(for: Locale(identifier: "ja_JP")).temperatureUnit == .celsius
        )
    }

    @Test
    func testNormalizedPreferencesPreventInvertedTemperatureRange() {
        var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
        preferences.idealMinimumFahrenheit = 70
        preferences.idealMaximumFahrenheit = 65

        #expect(preferences.normalized.idealMinimumFahrenheit == 70)
        #expect(preferences.normalized.idealMaximumFahrenheit == 70)
    }

    @Test
    func testResetSliderDefaultsPreservesNonSliderPreferences() {
        let locale = Locale(identifier: "en_US")
        let defaults = ComfortPreferences.default(for: locale)
        var preferences = defaults
        preferences.idealMinimumFahrenheit = 40
        preferences.idealMaximumFahrenheit = 90
        preferences.maximumDewPointFahrenheit = 70
        preferences.maximumRainChance = 0.75
        preferences.maximumWindMPH = 30
        preferences.temperatureUnit = .celsius
        preferences.alertsEnabled = false

        preferences.resetSliderDefaults(for: locale)

        #expect(preferences.idealMinimumFahrenheit == defaults.idealMinimumFahrenheit)
        #expect(preferences.idealMaximumFahrenheit == defaults.idealMaximumFahrenheit)
        #expect(preferences.maximumDewPointFahrenheit == defaults.maximumDewPointFahrenheit)
        #expect(preferences.maximumRainChance == defaults.maximumRainChance)
        #expect(preferences.maximumWindMPH == defaults.maximumWindMPH)
        #expect(preferences.temperatureUnit == .celsius)
        #expect(!preferences.alertsEnabled)
    }
}
