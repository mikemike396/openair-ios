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

private struct DashboardPreview: View {
    @State private var preferences: UserPreferenceStore
    @State private var weather: WeatherStore
    @State private var location: LocationStore
    @State private var notifications: NotificationStore
    @State private var coordinator: AppCoordinator

    init(state: DashboardLoadState) {
        let defaults = UserDefaults(suiteName: "DashboardPreview.\(UUID().uuidString)")!
        let preferences = UserPreferenceStore(userDefaults: defaults)
        preferences.hasCompletedOnboarding = true
        let provider = LocationClient()
        let location = LocationStore(provider: provider, places: MapKitPlaceSearchClient(), preferences: preferences)
        let weather = WeatherStore(
            requests: WeatherRequestCoordinator(weather: PreviewWeatherClient(), location: provider, preferences: preferences),
            evaluator: RecommendationEngine(),
            cache: WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "preview-\(UUID()).json")),
            widgets: DisabledWidgetSnapshotPublisher(), preferences: preferences
        )
        let notifications = NotificationStore(scheduler: NotificationClient(), preferences: preferences)
        let coordinator = AppCoordinator(
            weather: weather, location: location, notifications: notifications,
            preferences: preferences, reviews: AppReviewManager(userPreferences: preferences),
            background: PreviewBackgroundRefreshClient()
        )
        weather.loadState = state
        _preferences = State(initialValue: preferences)
        _weather = State(initialValue: weather)
        _location = State(initialValue: location)
        _notifications = State(initialValue: notifications)
        _coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        NavigationStack {
            DashboardView()
        }
        .environment(weather)
        .environment(location)
        .environment(notifications)
        .environment(\.userPreferenceStore, preferences)
        .environment(\.appCoordinator, coordinator)
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
        let plan = RecommendationEngine().plan(snapshot: snapshot, preferences: .default(for: .autoupdatingCurrent))
        return DashboardPreview(state: .loaded(snapshot: snapshot, plan: plan))
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

}

private final class PreviewBackgroundRefreshClient: BackgroundRefreshManaging {
    func beginLocationUpdate(expiration: @escaping @MainActor () -> Void) {}
    func endLocationUpdate() {}
    func scheduleRefresh() {}
}
