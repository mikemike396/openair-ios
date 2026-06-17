import Foundation
import Testing
@testable import OpenAir

@Suite
@MainActor
struct RecommendationEngineTests {
    private let engine = RecommendationEngine()
    private let preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func idealBoundariesAreOpen() {
        #expect(engine.evaluate(weather(temp: 52), preferences: preferences).status == .open)
        #expect(engine.evaluate(weather(temp: 78), preferences: preferences).status == .open)
        #expect(engine.evaluate(weather(dewPoint: 60), preferences: preferences).status == .open)
        #expect(engine.evaluate(weather(rain: 0.199), preferences: preferences).status == .open)
        #expect(engine.evaluate(weather(wind: 20), preferences: preferences).status == .open)
        #expect(engine.evaluate(weather(gust: 30), preferences: preferences).status == .open)
    }

    @Test
    func rainAboveThresholdClosesWindows() {
        let result = engine.evaluate(weather(rain: 0.501), preferences: preferences)

        #expect(result.status == .keepClosed)
        #expect(result.reasons.contains(.rainRisk))
    }

    @Test
    func rainProbabilityAtOrBelowThresholdAllowsOpen() {
        #expect(engine.evaluate(weather(rain: 0.50), preferences: preferences).status == .open)
        #expect(engine.evaluate(weather(rain: 0.499), preferences: preferences).status == .open)
    }

    @Test
    func eachHardCloseConditionWins() {
        #expect(engine.evaluate(weather(precipitating: true), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(thunderstorm: true), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(gust: 36), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(temp: 44.9), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(temp: 85.1), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(dewPoint: 68.1), preferences: preferences).status == .keepClosed)
    }

    @Test
    func maximumGustPreferenceControlsGustClosures() {
        var preferences = preferences
        preferences.maximumGustMPH = 40

        #expect(engine.evaluate(weather(gust: 40), preferences: preferences).status == .open)
        #expect(engine.evaluate(weather(gust: 41), preferences: preferences).status == .keepClosed)
    }

    @Test
    func anyComfortThresholdMissClosesWindows() {
        #expect(engine.evaluate(weather(temp: 80), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(dewPoint: 64), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(rain: 0.501), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(wind: 21), preferences: preferences).status == .keepClosed)
        #expect(engine.evaluate(weather(temp: 80, dewPoint: 64, wind: 21), preferences: preferences).status == .keepClosed)
    }

    @Test
    func displayedDewPointAtMaximumAllowsOpenDespiteHiddenDecimal() {
        #expect(engine.evaluate(weather(dewPoint: 62.49), preferences: preferences).status == .open)
    }

    @Test
    func displayedTemperatureAtMaximumAllowsOpenDespiteHiddenDecimal() {
        #expect(engine.evaluate(weather(temp: 78.49), preferences: preferences).status == .open)
    }

    @Test
    func displayedWindAtMaximumAllowsOpenDespiteHiddenDecimal() {
        #expect(engine.evaluate(weather(wind: 20.49), preferences: preferences).status == .open)
    }

    @Test
    func displayedGustAtMaximumAllowsOpenDespiteHiddenDecimal() {
        #expect(engine.evaluate(weather(gust: 30.49), preferences: preferences).status == .open)
    }

    @Test
    func invertedTemperatureRangeDoesNotCrashRecommendation() {
        var preferences = preferences
        preferences.idealMinimumFahrenheit = 70
        preferences.idealMaximumFahrenheit = 65

        _ = engine.evaluate(weather(temp: 70), preferences: preferences)
    }

    @Test
    func consecutiveHoursMergeIntoWindows() {
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

        #expect(plan.windows.count == 2)
        #expect(plan.windows[0].status == .open)
        #expect(plan.windows[0].start == hours[0].date)
        #expect(plan.windows[0].end == hours[2].date)
        #expect(plan.windows[1].status == .keepClosed)
        #expect(plan.nextChange == hours[2].date)
    }

    @Test
    func planStartsWithCurrentConditionsAndSkipsElapsedHourlyBuckets() {
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

        #expect(plan.hourly.map(\.weather) == [current, nextHour, followingHour])
    }

    @Test
    func nextChangeUsesUpcomingForecastAfterCurrentConditions() {
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

        #expect(plan.current.status == .open)
        #expect(plan.nextChange == followingClosedHour.date)
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
