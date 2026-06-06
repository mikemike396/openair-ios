import BackgroundTasks
import CoreLocation
import Foundation
import Observation
import UserNotifications

enum DashboardLoadState {
    case idle
    case loading
    case loaded(snapshot: WeatherSnapshot, plan: RecommendationPlan, isOffline: Bool)
    case failed(message: String, cached: WeatherSnapshot?)
}

@MainActor
@Observable
final class AppStore {
    private let weather: any WeatherProviding
    let location: any LocationProviding
    private let places: any PlaceSearching
    private let evaluator: any RecommendationEvaluating
    private let notifications: any NotificationScheduling
    private let cache: WeatherCache
    private let defaults: UserDefaults

    var loadState: DashboardLoadState = .idle
    var searchResults: [SavedPlace] = []
    var isSearching = false
    var searchError: String?
    var notificationStatus: UNAuthorizationStatus = .notDetermined

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    var savedPlace: SavedPlace? {
        didSet { encode(savedPlace, key: Keys.place) }
    }

    var preferences: ComfortPreferences {
        didSet {
            encode(preferences, key: Keys.preferences)
            recalculate()
        }
    }

    init(
        weather: any WeatherProviding = WeatherKitClient(),
        location: any LocationProviding = LocationClient(),
        places: any PlaceSearching = MapKitPlaceSearchClient(),
        evaluator: any RecommendationEvaluating = RecommendationEngine(),
        notifications: any NotificationScheduling = NotificationClient(),
        cache: WeatherCache = WeatherCache(),
        defaults: UserDefaults = .standard
    ) {
        self.weather = weather
        self.location = location
        self.places = places
        self.evaluator = evaluator
        self.notifications = notifications
        self.cache = cache
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        savedPlace = Self.decode(SavedPlace.self, key: Keys.place, defaults: defaults)
        preferences = Self.decode(ComfortPreferences.self, key: Keys.preferences, defaults: defaults) ?? .default
    }

    func start() async {
        notificationStatus = await notifications.authorizationStatus()
        guard hasCompletedOnboarding else { return }
        await refresh()
    }

    func requestLocationPermission() {
        location.requestAuthorization()
    }

    func requestNotificationPermission() async {
        _ = try? await notifications.requestAuthorization()
        notificationStatus = await notifications.authorizationStatus()
    }

    func completeOnboarding() async {
        hasCompletedOnboarding = true
        await refresh()
    }

    func searchPlaces(_ query: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await places.search(query: query)
            searchError = nil
        } catch is CancellationError {
            return
        } catch {
            searchError = error.localizedDescription
            searchResults = []
        }
    }

    func choose(place: SavedPlace) {
        savedPlace = place
        searchResults = []
    }

    func useCurrentLocation() {
        savedPlace = nil
    }

    func refresh() async {
        loadState = .loading
        do {
            let target = try await weatherTarget()
            let snapshot = try await weather.fetchWeather(for: target.coordinate, locationName: target.name)
            cache.save(snapshot)
            let plan = evaluator.plan(snapshot: snapshot, preferences: preferences)
            loadState = .loaded(snapshot: snapshot, plan: plan, isOffline: false)
            await notifications.replaceNotifications(
                plan: plan,
                locationName: snapshot.locationName,
                enabled: preferences.alertsEnabled
            )
            scheduleBackgroundRefresh()
        } catch {
            if let cached = cache.load() {
                let plan = evaluator.plan(snapshot: cached, preferences: preferences)
                loadState = .loaded(snapshot: cached, plan: plan, isOffline: true)
            } else {
                loadState = .failed(message: error.localizedDescription, cached: nil)
            }
        }
    }

    func usePreviewWeather() async {
        let snapshot = WeatherSnapshot.preview
        let plan = evaluator.plan(snapshot: snapshot, preferences: preferences)
        loadState = .loaded(snapshot: snapshot, plan: plan, isOffline: true)
    }

    private func weatherTarget() async throws -> (coordinate: Coordinate, name: String) {
        if let savedPlace {
            return (savedPlace.coordinate, savedPlace.name)
        }
        let coordinate = try await location.requestLocation()
        return (coordinate, "Current Location")
    }

    private func recalculate() {
        guard case .loaded(let snapshot, _, let isOffline) = loadState else { return }
        let plan = evaluator.plan(snapshot: snapshot, preferences: preferences)
        loadState = .loaded(snapshot: snapshot, plan: plan, isOffline: isOffline)
        Task {
            await notifications.replaceNotifications(
                plan: plan,
                locationName: snapshot.locationName,
                enabled: preferences.alertsEnabled
            )
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: OpenAirApp.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func encode<T: Encodable>(_ value: T?, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private enum Keys {
        static let onboarding = "hasCompletedOnboarding"
        static let place = "savedPlace"
        static let preferences = "comfortPreferences"
    }
}
