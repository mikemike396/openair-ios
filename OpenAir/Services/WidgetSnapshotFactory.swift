import Foundation

struct WidgetSnapshotFactory {
    func makeSnapshot(
        weather: WeatherSnapshot,
        plan: RecommendationPlan,
        preferences: ComfortPreferences
    ) -> OpenAirWidgetSnapshot {
        let unit = preferences.temperatureUnit
        return OpenAirWidgetSnapshot(
            status: plan.current.status.widgetStatus,
            temperature: unit.display(weather.current.temperatureFahrenheit),
            dewPoint: unit.display(weather.current.dewPointFahrenheit),
            unitSymbol: unit.symbol,
            fetchedAt: weather.fetchedAt,
            locationName: weather.locationName
        )
    }
}

private extension RecommendationStatus {
    var widgetStatus: OpenAirWidgetRecommendationStatus {
        switch self {
        case .open: .open
        case .keepClosed: .keepClosed
        }
    }
}
