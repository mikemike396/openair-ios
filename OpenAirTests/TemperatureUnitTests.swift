import XCTest
@testable import OpenAir

@MainActor
final class TemperatureUnitTests: XCTestCase {
    func testFahrenheitDisplayRounds() {
        XCTAssertEqual(TemperatureUnit.fahrenheit.display(64.6), 65)
    }

    func testCelsiusConversionAndRounding() {
        XCTAssertEqual(TemperatureUnit.celsius.display(32), 0)
        XCTAssertEqual(TemperatureUnit.celsius.display(68), 20)
    }

    func testDefaultPreferencesUseFahrenheitForUSLocale() {
        XCTAssertEqual(
            ComfortPreferences.default(for: Locale(identifier: "en_US")).temperatureUnit,
            .fahrenheit
        )
    }

    func testDefaultPreferencesUseCelsiusForMetricLocale() {
        XCTAssertEqual(
            ComfortPreferences.default(for: Locale(identifier: "ja_JP")).temperatureUnit,
            .celsius
        )
    }

    func testNormalizedPreferencesPreventInvertedTemperatureRange() {
        var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
        preferences.idealMinimumFahrenheit = 70
        preferences.idealMaximumFahrenheit = 65

        XCTAssertEqual(preferences.normalized.idealMinimumFahrenheit, 70)
        XCTAssertEqual(preferences.normalized.idealMaximumFahrenheit, 70)
    }

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

        XCTAssertEqual(preferences.idealMinimumFahrenheit, defaults.idealMinimumFahrenheit)
        XCTAssertEqual(preferences.idealMaximumFahrenheit, defaults.idealMaximumFahrenheit)
        XCTAssertEqual(preferences.maximumDewPointFahrenheit, defaults.maximumDewPointFahrenheit)
        XCTAssertEqual(preferences.maximumRainChance, defaults.maximumRainChance)
        XCTAssertEqual(preferences.maximumWindMPH, defaults.maximumWindMPH)
        XCTAssertEqual(preferences.temperatureUnit, .celsius)
        XCTAssertFalse(preferences.alertsEnabled)
    }
}
