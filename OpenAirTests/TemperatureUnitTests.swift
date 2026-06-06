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
}
