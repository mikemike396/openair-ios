import XCTest
@testable import OpenAir

final class RecommendationEngineTests: XCTestCase {
    private let engine = RecommendationEngine()
    private let preferences = ComfortPreferences.default
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testIdealBoundariesAreOpen() {
        XCTAssertEqual(engine.evaluate(weather(temp: 55), preferences: preferences).status, .open)
        XCTAssertEqual(engine.evaluate(weather(temp: 75), preferences: preferences).status, .open)
        XCTAssertEqual(engine.evaluate(weather(dewPoint: 60), preferences: preferences).status, .open)
        XCTAssertEqual(engine.evaluate(weather(rain: 0.199), preferences: preferences).status, .open)
        XCTAssertEqual(engine.evaluate(weather(wind: 15), preferences: preferences).status, .open)
    }

    func testRainThresholdIsMarginal() {
        let result = engine.evaluate(weather(rain: 0.20), preferences: preferences)
        XCTAssertEqual(result.status, .good)
        XCTAssertTrue(result.reasons.contains(.rainRisk))
    }

    func testEachHardCloseConditionWins() {
        XCTAssertEqual(engine.evaluate(weather(precipitating: true), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(thunderstorm: true), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(gust: 25), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(temp: 44.9), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(temp: 85.1), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(dewPoint: 68.1), preferences: preferences).status, .keepClosed)
    }

    func testMultipleMissesDegradeCategory() {
        XCTAssertEqual(engine.evaluate(weather(temp: 80), preferences: preferences).status, .good)
        XCTAssertEqual(engine.evaluate(weather(temp: 80, dewPoint: 64), preferences: preferences).status, .marginal)
        XCTAssertEqual(engine.evaluate(weather(temp: 80, dewPoint: 64, wind: 20), preferences: preferences).status, .keepClosed)
    }

    func testConsecutiveHoursMergeIntoWindows() {
        let hours = [
            weather(date: start, temp: 65),
            weather(date: start.addingTimeInterval(3600), temp: 66),
            weather(date: start.addingTimeInterval(7200), temp: 86),
            weather(date: start.addingTimeInterval(10800), temp: 87)
        ]
        let snapshot = WeatherSnapshot(
            locationName: "Test",
            coordinate: .init(latitude: 0, longitude: 0),
            fetchedAt: start,
            current: hours[0],
            hourly: hours
        )

        let plan = engine.plan(snapshot: snapshot, preferences: preferences)

        XCTAssertEqual(plan.windows.count, 2)
        XCTAssertEqual(plan.windows[0].status, .open)
        XCTAssertEqual(plan.windows[0].start, hours[0].date)
        XCTAssertEqual(plan.windows[0].end, hours[2].date)
        XCTAssertEqual(plan.windows[1].status, .keepClosed)
        XCTAssertEqual(plan.nextChange, hours[2].date)
    }

    private func weather(
        date: Date? = nil,
        temp: Double = 65,
        dewPoint: Double = 55,
        rain: Double = 0.1,
        wind: Double = 10,
        gust: Double? = 15,
        precipitating: Bool = false,
        thunderstorm: Bool = false
    ) -> HourlyWeather {
        HourlyWeather(
            date: date ?? start,
            temperatureFahrenheit: temp,
            dewPointFahrenheit: dewPoint,
            precipitationChance: rain,
            isPrecipitating: precipitating,
            isThunderstorm: thunderstorm,
            windMPH: wind,
            gustMPH: gust,
            symbolName: "sun.max"
        )
    }
}
