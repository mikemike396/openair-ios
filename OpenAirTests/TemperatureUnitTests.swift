import XCTest
@testable import OpenAir

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
}
