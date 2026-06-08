import XCTest
@testable import OpenAir

final class RecommendationEngineTests: XCTestCase {
    private let engine = RecommendationEngine()
    private let preferences = ComfortPreferences.default(for: .autoupdatingCurrent)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testIdealBoundariesAreOpen() {
        XCTAssertEqual(engine.evaluate(weather(temp: 52), preferences: preferences).status, .open)
        XCTAssertEqual(engine.evaluate(weather(temp: 78), preferences: preferences).status, .open)
        XCTAssertEqual(engine.evaluate(weather(dewPoint: 60), preferences: preferences).status, .open)
        XCTAssertEqual(engine.evaluate(weather(rain: 0.199), preferences: preferences).status, .open)
        XCTAssertEqual(engine.evaluate(weather(wind: 15), preferences: preferences).status, .open)
    }

    func testRainThresholdClosesWindows() {
        let result = engine.evaluate(weather(rain: 0.50), preferences: preferences)
        XCTAssertEqual(result.status, .keepClosed)
        XCTAssertTrue(result.reasons.contains(.rainRisk))
    }

    func testRainProbabilityBelowThresholdAllowsOpen() {
        XCTAssertEqual(engine.evaluate(weather(rain: 0.499), preferences: preferences).status, .open)
    }

    func testEachHardCloseConditionWins() {
        XCTAssertEqual(engine.evaluate(weather(precipitating: true), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(thunderstorm: true), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(gust: 25), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(temp: 44.9), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(temp: 85.1), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(dewPoint: 68.1), preferences: preferences).status, .keepClosed)
    }

    func testAnyComfortThresholdMissClosesWindows() {
        XCTAssertEqual(engine.evaluate(weather(temp: 80), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(dewPoint: 64), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(rain: 0.50), preferences: preferences).status, .keepClosed)
        XCTAssertEqual(engine.evaluate(weather(wind: 16), preferences: preferences).status, .keepClosed)
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

    func testPlanStartsWithCurrentConditionsAndSkipsElapsedHourlyBuckets() {
        let current = weather(date: start.addingTimeInterval(50 * 60), temp: 70)
        let elapsedHour = weather(date: start, temp: 55)
        let nextHour = weather(date: start.addingTimeInterval(3600), temp: 72)
        let followingHour = weather(date: start.addingTimeInterval(7200), temp: 74)
        let snapshot = WeatherSnapshot(
            locationName: "Test",
            coordinate: .init(latitude: 0, longitude: 0),
            fetchedAt: current.date,
            current: current,
            hourly: [elapsedHour, nextHour, followingHour]
        )

        let plan = engine.plan(snapshot: snapshot, preferences: preferences)

        XCTAssertEqual(plan.hourly.map(\.weather), [current, nextHour, followingHour])
    }

    func testNextChangeUsesUpcomingForecastAfterCurrentConditions() {
        let current = weather(date: start.addingTimeInterval(50 * 60), temp: 70)
        let elapsedClosedHour = weather(date: start, temp: 86)
        let nextOpenHour = weather(date: start.addingTimeInterval(3600), temp: 72)
        let followingClosedHour = weather(date: start.addingTimeInterval(7200), temp: 86)
        let snapshot = WeatherSnapshot(
            locationName: "Test",
            coordinate: .init(latitude: 0, longitude: 0),
            fetchedAt: current.date,
            current: current,
            hourly: [elapsedClosedHour, nextOpenHour, followingClosedHour]
        )

        let plan = engine.plan(snapshot: snapshot, preferences: preferences)

        XCTAssertEqual(plan.current.status, .open)
        XCTAssertEqual(plan.nextChange, followingClosedHour.date)
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
