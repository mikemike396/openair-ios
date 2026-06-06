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
    private static let foregroundRefreshInterval: TimeInterval = 60 * 15

    private let weather: any WeatherProviding
    let location: any LocationProviding
    private let places: any PlaceSearching
    private let evaluator: any RecommendationEvaluating
    private let notifications: any NotificationScheduling
    private let cache: WeatherCache
    private let defaults: UserDefaults

    var loadState: DashboardLoadState = .idle
    private(set) var isRefreshing = false
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
        encode(preferences, key: Keys.preferences)
        if hasCompletedOnboarding, let cached = cache.load() {
            let plan = evaluator.plan(snapshot: cached, preferences: preferences)
            loadState = .loaded(snapshot: cached, plan: plan, isOffline: false)
        }
    }

    func start() async {
        notificationStatus = await notifications.authorizationStatus()
        guard hasCompletedOnboarding else { return }
        await refresh(preservingLoadedState: true)
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
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchError = nil
            return
        }

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

    func clearSearchResults() {
        searchResults = []
        searchError = nil
    }

    func choose(place: SavedPlace) {
        savedPlace = place
        searchResults = []
        searchError = nil
    }

    func chooseAndRefresh(place: SavedPlace) async {
        choose(place: place)
        guard hasCompletedOnboarding else { return }
        await refresh()
    }

    func useCurrentLocation() async -> Bool {
        savedPlace = nil
        searchResults = []
        do {
            _ = try await location.requestLocation()
            searchError = nil
            if hasCompletedOnboarding {
                await refresh()
            }
            return true
        } catch {
            searchError = error.localizedDescription
            return false
        }
    }

    func refresh() async {
        await refresh(preservingLoadedState: false)
    }

    func refreshPreservingLoadedState() async {
        await refresh(preservingLoadedState: true)
    }

    private func refresh(preservingLoadedState: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let existingSnapshot: WeatherSnapshot?
        if preservingLoadedState,
           case .loaded(let snapshot, _, _) = loadState {
            existingSnapshot = snapshot
        } else {
            existingSnapshot = nil
            loadState = .loading
        }

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
            if let cached = existingSnapshot ?? cache.load() {
                let plan = evaluator.plan(snapshot: cached, preferences: preferences)
                loadState = .loaded(snapshot: cached, plan: plan, isOffline: true)
            } else {
                loadState = .failed(message: error.localizedDescription, cached: nil)
            }
        }
    }

    func refreshIfNeeded(now: Date = .now) async {
        guard hasCompletedOnboarding else { return }

        switch loadState {
        case .idle, .failed:
            await refresh()
        case .loading:
            return
        case .loaded(let snapshot, _, _):
            guard now.timeIntervalSince(snapshot.fetchedAt) >= Self.foregroundRefreshInterval else { return }
            await refresh(preservingLoadedState: true)
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
        let name = await location.placename(for: coordinate) ?? "Current Location"
        return (coordinate, name)
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
