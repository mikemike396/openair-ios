import Foundation
import Testing
@testable import OpenAir

@MainActor
struct RecommendationPlanSmoothingTests {
    private let engine = RecommendationEngine()
    private let preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func nextChangeSkipsOneHourTransientChange() {
        let hours = [
            weather(hour: 0, temperature: 65),
            weather(hour: 1, temperature: 80),
            weather(hour: 2, temperature: 65),
            weather(hour: 3, temperature: 65),
            weather(hour: 4, temperature: 80),
            weather(hour: 5, temperature: 80)
        ]

        let plan = engine.plan(snapshot: snapshot(hours: hours), preferences: preferences)

        #expect(plan.windows.map(\.status) == [.open, .keepClosed])
        #expect(plan.nextChange == hours[4].date)
    }

    @Test
    func nextChangeKeepsOneHourSafetyChange() {
        let hours = [
            weather(hour: 0, temperature: 65),
            weather(hour: 1, temperature: 65, thunderstorm: true),
            weather(hour: 2, temperature: 65)
        ]

        let plan = engine.plan(snapshot: snapshot(hours: hours), preferences: preferences)

        #expect(plan.windows.map(\.status) == [.open, .keepClosed, .open])
        #expect(plan.nextChange == hours[1].date)
    }

    private func snapshot(hours: [HourlyWeather]) -> WeatherSnapshot {
        WeatherSnapshot(
            locationName: "Test",
            coordinate: .init(latitude: 0, longitude: 0),
            fetchedAt: start,
            current: hours[0],
            hourly: hours
        )
    }

    private func weather(
        hour: Int,
        temperature: Double,
        thunderstorm: Bool = false
    ) -> HourlyWeather {
        HourlyWeather(
            date: start.addingTimeInterval(Double(hour) * 3600),
            temperatureFahrenheit: temperature,
            dewPointFahrenheit: 55,
            precipitationChance: 0.1,
            isPrecipitating: false,
            isThunderstorm: thunderstorm,
            windMPH: 10,
            gustMPH: 15,
            symbolName: "sun.max"
        )
    }
}
