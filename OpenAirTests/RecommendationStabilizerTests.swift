import Foundation
import Testing
@testable import OpenAir

@Suite
struct RecommendationStabilizerTests {
    private let engine = RecommendationEngine()
    private let preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let home = Coordinate(latitude: 39.7391, longitude: -75.5398)

    @Test
    func cachedRainDoesNotRestartHoldAndFreshDrynessIsRequired() {
        var state = RecommendationStabilizationState()
        let rainy = snapshot(at: start, raining: true)
        #expect(plan(rainy, state: &state, fresh: true).current.status == .keepClosed)
        let recordedRain = state.lastRainAt
        #expect(plan(rainy, state: &state, fresh: false).current.status == .keepClosed)
        #expect(state.lastRainAt == recordedRain)
        let earlyDry = snapshot(at: start.addingTimeInterval(90 * 60))
        #expect(plan(earlyDry, state: &state, fresh: true).current.reasons.contains(.recentRain))
        #expect(plan(earlyDry, state: &state, fresh: false).current.reasons.contains(.recentRain))
        #expect(state.lastRainAt == recordedRain)
        let recovered = snapshot(at: start.addingTimeInterval(2 * 60 * 60))
        #expect(plan(recovered, state: &state, fresh: true).current.status == .open)
    }

    @Test
    func rainRecoveryRequiresTwoDryForecastHours() {
        var state = RecommendationStabilizationState()
        _ = plan(snapshot(at: start, raining: true), state: &state, fresh: true)
        let later = start.addingTimeInterval(3 * 60 * 60)
        let forecastRain = snapshot(at: later, nextHourRaining: true)
        #expect(plan(forecastRain, state: &state, fresh: true).current.reasons.contains(.recentRain))
        #expect(plan(snapshot(at: later.addingTimeInterval(60 * 60)), state: &state, fresh: true).current.status == .open)
    }

    @Test
    func ordinaryChangeNeedsObservationsAnHourApart() {
        var state = RecommendationStabilizationState()
        _ = plan(snapshot(at: start), state: &state, fresh: true)
        let hot = snapshot(at: start.addingTimeInterval(15 * 60), temperature: 80)
        #expect(plan(hot, state: &state, fresh: true).current.status == .open)
        #expect(state.pendingStatus == .keepClosed)
        #expect(plan(hot, state: &state, fresh: false).current.status == .open)
        #expect(state.pendingSince == hot.fetchedAt)
        let confirmed = snapshot(at: start.addingTimeInterval(75 * 60), temperature: 80)
        #expect(plan(confirmed, state: &state, fresh: true).current.status == .keepClosed)
    }

    @Test
    func preferenceRecalculationPreservesRainAndEffectiveStatus() {
        var state = RecommendationStabilizationState()
        let rainy = snapshot(at: start, raining: true)
        _ = plan(rainy, state: &state, fresh: true)
        let rainAt = state.lastRainAt
        state.resetForPreferenceChange()
        #expect(state.lastRainAt == rainAt)
        #expect(plan(snapshot(at: start.addingTimeInterval(30 * 60)), state: &state, fresh: false).current.status == .keepClosed)
    }

    @Test
    func travelOverFiveKilometersResetsRainHistory() {
        var state = RecommendationStabilizationState()
        _ = plan(snapshot(at: start, raining: true), state: &state, fresh: true)
        let far = Coordinate(latitude: 39.85, longitude: -75.5398)
        let result = plan(snapshot(at: start.addingTimeInterval(15 * 60), coordinate: far), state: &state, fresh: true)
        #expect(result.current.status == .open)
        #expect(state.lastRainAt == nil)
        #expect(state.coordinate == far)
    }

    private func plan(
        _ snapshot: WeatherSnapshot,
        state: inout RecommendationStabilizationState,
        fresh: Bool
    ) -> RecommendationPlan {
        state.plan(for: snapshot, base: engine.plan(snapshot: snapshot, preferences: preferences), preferences: preferences, fresh: fresh)
    }

    private func snapshot(
        at date: Date,
        coordinate: Coordinate? = nil,
        temperature: Double = 65,
        raining: Bool = false,
        nextHourRaining: Bool = false
    ) -> WeatherSnapshot {
        func hour(_ offset: TimeInterval, rain: Bool) -> HourlyWeather {
            HourlyWeather(
                date: date.addingTimeInterval(offset),
                temperatureFahrenheit: temperature,
                dewPointFahrenheit: 55,
                precipitationChance: 0.1,
                isPrecipitating: rain,
                isThunderstorm: false,
                windMPH: 10,
                gustMPH: 15,
                symbolName: rain ? "cloud.rain" : "sun.max"
            )
        }
        let current = hour(0, rain: raining)
        return WeatherSnapshot(
            locationName: "Test",
            coordinate: coordinate ?? home,
            fetchedAt: date,
            current: current,
            hourly: [current, hour(3600, rain: nextHourRaining), hour(7200, rain: false), hour(10800, rain: false)]
        )
    }
}
