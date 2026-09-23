import CoreLocation
import Foundation

/// Only a successful, new weather snapshot advances this state. Rendering cached
/// weather must never extend a rain hold or confirm a pending change.
struct RecommendationStabilizationState: Codable, Sendable, Equatable {
    var coordinate: Coordinate?
    var effective: Recommendation?
    var pendingStatus: RecommendationStatus?
    var pendingSince: Date?
    var lastRainAt: Date?
    var awaitingRainRecovery = false
    var lastObservationAt: Date?

    mutating func resetForPreferenceChange() {
        pendingStatus = nil
        pendingSince = nil
    }

    mutating func plan(
        for snapshot: WeatherSnapshot,
        base: RecommendationPlan,
        preferences: ComfortPreferences,
        fresh: Bool
    ) -> RecommendationPlan {
        let observationIsNew = fresh && snapshot.fetchedAt > (lastObservationAt ?? .distantPast)
        if observationIsNew, let coordinate,
           coordinate.clLocation.distance(from: snapshot.coordinate.clLocation) > 5_000 {
            self = Self()
        }

        if effective == nil {
            effective = base.current
            coordinate = snapshot.coordinate
            // A cached rainy snapshot is evidence of rain at its original fetch
            // time, never at the time the cache was opened.
            if snapshot.current.isPrecipitating {
                lastRainAt = snapshot.fetchedAt
                awaitingRainRecovery = true
            }
            lastObservationAt = snapshot.fetchedAt
        } else if observationIsNew {
            let raw = base.current
            let now = snapshot.fetchedAt
            if snapshot.current.isPrecipitating {
                lastRainAt = now
                awaitingRainRecovery = true
            }

            let rainRecovered = awaitingRainRecovery &&
                !snapshot.current.isPrecipitating &&
                raw.status == .open &&
                now.timeIntervalSince(lastRainAt ?? now) >= 2 * 60 * 60 &&
                Self.twoDryHours(in: base.hourly, startingAt: 1, preferences: preferences)

            if rainRecovered {
                awaitingRainRecovery = false
                effective = raw
                pendingStatus = nil
                pendingSince = nil
            } else if awaitingRainRecovery && raw.status == .open {
                effective = Recommendation(status: .keepClosed, reasons: [.recentRain])
                pendingStatus = nil
                pendingSince = nil
            } else if raw.reasons.contains(where: { !$0.allowsTransientSmoothing }) {
                effective = raw
                pendingStatus = nil
                pendingSince = nil
            } else if raw.status == effective?.status {
                effective = raw
                pendingStatus = nil
                pendingSince = nil
            } else if pendingStatus == raw.status,
                      now.timeIntervalSince(pendingSince ?? now) >= 60 * 60 {
                effective = raw
                pendingStatus = nil
                pendingSince = nil
            } else if pendingStatus != raw.status {
                pendingStatus = raw.status
                pendingSince = now
            }
            coordinate = snapshot.coordinate
            lastObservationAt = now
        }

        let current = effective ?? base.current
        if awaitingRainRecovery, current.status == .keepClosed,
           !current.reasons.contains(.recentRain), !current.reasons.contains(.activePrecipitation) {
            effective = Recommendation(status: .keepClosed, reasons: [.recentRain] + current.reasons)
        }
        let displayedCurrent = effective ?? current
        var hourly: [(weather: HourlyWeather, recommendation: Recommendation)] = []
        var forecastRainAt = awaitingRainRecovery ? lastRainAt : nil
        for index in base.hourly.indices {
            let item = base.hourly[index]
            if index == 0 {
                hourly.append((item.weather, displayedCurrent))
                continue
            }
            var recommendation = item.recommendation
            if item.weather.isPrecipitating {
                forecastRainAt = item.weather.date
            } else if recommendation.status == .open, let lastForecastRainAt = forecastRainAt {
                let elapsed = item.weather.date.timeIntervalSince(lastForecastRainAt)
                if elapsed < 2 * 60 * 60 ||
                    !Self.twoDryHours(in: base.hourly, startingAt: index, preferences: preferences) {
                    recommendation = Recommendation(status: .keepClosed, reasons: [.recentRain])
                } else {
                    forecastRainAt = nil
                }
            }
            hourly.append((item.weather, recommendation))
        }

        let windows = Self.windows(from: hourly)
        let nextChange = windows.first { $0.start > snapshot.current.date && $0.status != displayedCurrent.status }?.start
        return RecommendationPlan(current: displayedCurrent, hourly: hourly, windows: windows, nextChange: nextChange)
    }

    private static func twoDryHours(
        in hourly: [(weather: HourlyWeather, recommendation: Recommendation)],
        startingAt index: Int,
        preferences: ComfortPreferences
    ) -> Bool {
        guard hourly.count >= index + 2 else { return false }
        return hourly[index..<(index + 2)].allSatisfy { item in
            !item.weather.isPrecipitating && !item.weather.isThunderstorm &&
                item.weather.precipitationChance <= preferences.maximumRainChance
        }
    }

    private static func windows(
        from hourly: [(weather: HourlyWeather, recommendation: Recommendation)]
    ) -> [RecommendationWindow] {
        guard let first = hourly.first else { return [] }
        var windows: [RecommendationWindow] = []
        var start = first.weather.date
        var status = first.recommendation.status
        var reasons = first.recommendation.reasons
        for item in hourly.dropFirst() {
            if item.recommendation.status != status {
                windows.append(.init(start: start, end: item.weather.date, status: status, reasons: reasons))
                start = item.weather.date
                status = item.recommendation.status
                reasons = item.recommendation.reasons
            } else {
                reasons = reasons.merging(item.recommendation.reasons)
            }
        }
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: hourly.last?.weather.date ?? start) ?? start
        windows.append(.init(start: start, end: end, status: status, reasons: reasons))
        return windows.mergingTransientStatusChanges()
    }
}
