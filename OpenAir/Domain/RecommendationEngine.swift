import Foundation

protocol RecommendationEvaluating: Sendable {
    func evaluate(_ weather: HourlyWeather, preferences: ComfortPreferences) -> Recommendation
    func plan(snapshot: WeatherSnapshot, preferences: ComfortPreferences) -> RecommendationPlan
}

struct RecommendationEngine: RecommendationEvaluating {
    func evaluate(_ weather: HourlyWeather, preferences: ComfortPreferences) -> Recommendation {
        if weather.isThunderstorm {
            return .init(status: .keepClosed, reasons: [.thunderstorm])
        }
        if weather.isPrecipitating {
            return .init(status: .keepClosed, reasons: [.activePrecipitation])
        }
        if weather.gustMPH ?? 0 >= 25 {
            return .init(status: .keepClosed, reasons: [.dangerousGusts])
        }
        if weather.temperatureFahrenheit < 45 || weather.temperatureFahrenheit > 85 {
            return .init(status: .keepClosed, reasons: [.extremeTemperature])
        }
        if weather.dewPointFahrenheit > 68 {
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
        let windows = makeWindows(from: evaluated)
        let nextChange = upcoming.first { $0.1.status != current.status }?.0.date
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

        for index in 1..<hourly.count where hourly[index].recommendation.status != status {
            let change = hourly[index]
            windows.append(.init(start: start, end: change.weather.date, status: status))
            start = change.weather.date
            status = change.recommendation.status
        }

        let end = Calendar.current.date(byAdding: .hour, value: 1, to: hourly.last?.weather.date ?? start) ?? start
        windows.append(.init(start: start, end: end, status: status))
        return windows
    }
}
