import Foundation

protocol RecommendationEvaluating: Sendable {
    func evaluate(_ weather: HourlyWeather, preferences: ComfortPreferences) -> Recommendation
    func plan(snapshot: WeatherSnapshot, preferences: ComfortPreferences) -> RecommendationPlan
}

struct RecommendationEngine: RecommendationEvaluating {
    func evaluate(_ weather: HourlyWeather, preferences: ComfortPreferences) -> Recommendation {
        let preferences = preferences.normalized
        if weather.isThunderstorm {
            return .init(status: .keepClosed, reasons: [.thunderstorm])
        }
        if weather.isPrecipitating {
            return .init(status: .keepClosed, reasons: [.activePrecipitation])
        }
        if let gustMPH = weather.gustMPH,
           !roundedDisplayValue(gustMPH, isAtMost: preferences.maximumGustMPH) {
            return .init(status: .keepClosed, reasons: [.dangerousGusts])
        }
        if weather.temperatureFahrenheit < .hardMinimumTemperatureFahrenheit ||
            weather.temperatureFahrenheit > .hardMaximumTemperatureFahrenheit {
            return .init(status: .keepClosed, reasons: [.extremeTemperature])
        }
        if weather.dewPointFahrenheit > .hardMaximumDewPointFahrenheit {
            return .init(status: .keepClosed, reasons: [.extremeHumidity])
        }

        var positive: [RecommendationReason] = []
        var negative: [RecommendationReason] = []

        if roundedDisplayValue(
            weather.temperatureFahrenheit,
            within: preferences.idealMinimumFahrenheit...preferences.idealMaximumFahrenheit,
            unit: preferences.temperatureUnit
        ) {
            positive.append(.comfortableTemperature)
        } else {
            negative.append(.temperatureOutsideRange)
        }

        if roundedDisplayValue(
            weather.dewPointFahrenheit,
            isAtMost: preferences.maximumDewPointFahrenheit,
            unit: preferences.temperatureUnit
        ) {
            positive.append(.lowDewPoint)
        } else {
            negative.append(.humid)
        }

        if weather.precipitationChance <= preferences.maximumRainChance {
            positive.append(.noRain)
        } else {
            negative.append(.rainRisk)
        }

        if roundedDisplayValue(weather.windMPH, isAtMost: preferences.maximumWindMPH) {
            positive.append(.lightWind)
        } else {
            negative.append(.windy)
        }

        return Recommendation(
            status: negative.isEmpty ? .open : .keepClosed,
            reasons: negative.isEmpty ? positive : negative
        )
    }

    func plan(snapshot: WeatherSnapshot, preferences: ComfortPreferences) -> RecommendationPlan {
        let current = evaluate(snapshot.current, preferences: preferences)
        let upcoming = snapshot.hourly
            .filter { $0.date > snapshot.current.date }
            .map { ($0, evaluate($0, preferences: preferences)) }
        let evaluated = [(snapshot.current, current)] + upcoming
        let windows = makeWindows(from: evaluated).mergingTransientStatusChanges()
        let nextChange = windows.first {
            $0.start > snapshot.current.date && $0.status != current.status
        }?.start
        return RecommendationPlan(current: current, hourly: evaluated, windows: windows, nextChange: nextChange)
    }

    private func roundedDisplayValue(
        _ value: Double,
        within range: ClosedRange<Double>,
        unit: TemperatureUnit
    ) -> Bool {
        let displayedValue = unit.display(value)
        return (unit.display(range.lowerBound)...unit.display(range.upperBound)).contains(displayedValue)
    }

    private func roundedDisplayValue(
        _ value: Double,
        isAtMost maximum: Double,
        unit: TemperatureUnit
    ) -> Bool {
        unit.display(value) <= unit.display(maximum)
    }

    private func roundedDisplayValue(
        _ value: Double,
        isAtMost maximum: Double
    ) -> Bool {
        Int(value.rounded()) <= Int(maximum.rounded())
    }

    private func makeWindows(
        from hourly: [(weather: HourlyWeather, recommendation: Recommendation)]
    ) -> [RecommendationWindow] {
        guard let first = hourly.first else { return [] }
        var windows: [RecommendationWindow] = []
        var start = first.weather.date
        var status = first.recommendation.status
        var reasons = first.recommendation.reasons

        for index in 1..<hourly.count {
            let item = hourly[index]
            if item.recommendation.status != status {
                windows.append(.init(start: start, end: item.weather.date, status: status, reasons: reasons))
                start = item.weather.date
                status = item.recommendation.status
                reasons = item.recommendation.reasons
            } else {
                reasons.append(contentsOf: item.recommendation.reasons.filter { !reasons.contains($0) })
            }
        }

        let end = Calendar.current.date(byAdding: .hour, value: 1, to: hourly.last?.weather.date ?? start) ?? start
        windows.append(.init(start: start, end: end, status: status, reasons: reasons))
        return windows
    }
}
