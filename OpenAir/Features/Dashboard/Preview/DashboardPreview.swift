import SwiftUI

#Preview("Loading") {
    DashboardPreview(state: .loading)
}

#Preview("Open") {
    DashboardPreview.loaded(status: .open)
}

#Preview("Closed") {
    DashboardPreview.loaded(status: .keepClosed)
}

#Preview("Stale / Offline") {
    DashboardPreview.loaded(status: .open, isOffline: true, isStale: true)
}

#Preview("Error") {
    DashboardPreview(state: .failed(message: "Weather service is unavailable.", cached: nil))
}

@MainActor
private struct DashboardPreview: View {
    @State private var store: AppStore

    init(state: DashboardLoadState) {
        let store = Self.makeStore()
        store.loadState = state
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            DashboardView()
        }
        .environment(store)
    }

    static func loaded(
        status: RecommendationStatus,
        isOffline: Bool = false,
        isStale: Bool = false
    ) -> DashboardPreview {
        let base = WeatherSnapshot.preview
        let current: HourlyWeather
        switch status {
        case .open:
            current = base.current
        case .keepClosed:
            current = replacing(base.current, temperature: 80, dewPoint: 64)
        }
        let snapshot = WeatherSnapshot(
            locationName: base.locationName,
            coordinate: base.coordinate,
            fetchedAt: isStale ? .now.addingTimeInterval(-60 * 60 * 4) : .now,
            current: current,
            hourly: [current] + Array(base.hourly.dropFirst())
        )
        let plan = RecommendationEngine().plan(snapshot: snapshot, preferences: .default)
        return DashboardPreview(state: .loaded(snapshot: snapshot, plan: plan, isOffline: isOffline))
    }

    private static func replacing(
        _ weather: HourlyWeather,
        temperature: Double,
        dewPoint: Double
    ) -> HourlyWeather {
        HourlyWeather(
            date: weather.date,
            temperatureFahrenheit: temperature,
            dewPointFahrenheit: dewPoint,
            precipitationChance: weather.precipitationChance,
            isPrecipitating: weather.isPrecipitating,
            isThunderstorm: weather.isThunderstorm,
            windMPH: weather.windMPH,
            gustMPH: weather.gustMPH,
            symbolName: weather.symbolName
        )
    }

    private static func makeStore() -> AppStore {
        let defaults = UserDefaults(suiteName: "DashboardPreview.\(UUID().uuidString)")!
        defaults.set(true, forKey: "hasCompletedOnboarding")
        return AppStore(weather: PreviewWeatherClient(), defaults: defaults)
    }
}
