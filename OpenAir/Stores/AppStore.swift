import BackgroundTasks
import CoreLocation
import Foundation
import Observation
import OSLog
import UserNotifications

enum DashboardLoadState {
    case idle
    case loading
    case loaded(snapshot: WeatherSnapshot, plan: RecommendationPlan)
    case failed(message: String, cached: WeatherSnapshot?)
}

enum RefreshResult: Equatable {
    case succeeded
    case failed
    case skipped
}

enum RefreshState: Equatable {
    case idle
    case refreshing
    case failed
}

@Observable
final class AppStore {
    private static let foregroundRefreshInterval: TimeInterval = 60 * 15

    private let weather: any WeatherProviding
    let location: any LocationProviding
    private let places: any PlaceSearching
    private let evaluator: any RecommendationEvaluating
    private let notifications: any NotificationScheduling
    private let cache: WeatherCache
    private var userPreferences: any UserPreferenceStoring

    var loadState: DashboardLoadState = .idle
    private(set) var refreshState: RefreshState = .idle
    var searchResults: [SavedPlace] = []
    var isSearching = false
    var searchError: String?
    var notificationStatus: UNAuthorizationStatus = .notDetermined

    var hasCompletedOnboarding: Bool {
        get {
            userPreferences.hasCompletedOnboarding
        }
        set {
            userPreferences.hasCompletedOnboarding = newValue
        }
    }

    var savedPlace: SavedPlace? {
        get {
            userPreferences.savedPlace
        }
        set {
            userPreferences.savedPlace = newValue
        }
    }

    var preferences: ComfortPreferences {
        get {
            userPreferences.preferences
        }
        set {
            userPreferences.preferences = newValue
            recalculate()
        }
    }

    init(
        weather: WeatherProviding = WeatherKitClient(),
        location: LocationProviding = LocationClient(),
        places: PlaceSearching = MapKitPlaceSearchClient(),
        evaluator: RecommendationEvaluating = RecommendationEngine(),
        notifications: NotificationScheduling = NotificationClient(),
        cache: WeatherCache = WeatherCache(),
        userPreferences: any UserPreferenceStoring = UserPreferenceStore()
    ) {
        self.weather = weather
        self.location = location
        self.places = places
        self.evaluator = evaluator
        self.notifications = notifications
        self.cache = cache
        self.userPreferences = userPreferences
        if hasCompletedOnboarding, let cached = cache.load() {
            let plan = evaluator.plan(snapshot: cached, preferences: preferences)
            loadState = .loaded(snapshot: cached, plan: plan)
        }
    }

    @discardableResult
    func start() async -> RefreshResult {
        notificationStatus = await notifications.authorizationStatus()
        guard hasCompletedOnboarding else { return .skipped }
        return await refreshIfNeeded()
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

    func searchPlacesAfterDebounce(_ query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            clearSearchResults()
            return
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        await searchPlaces(trimmedQuery)
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

    @discardableResult
    func refresh() async -> RefreshResult {
        await refresh(preservingLoadedState: false)
    }

    @discardableResult
    func refreshPreservingLoadedState() async -> RefreshResult {
        await refresh(preservingLoadedState: true)
    }

    private func refresh(preservingLoadedState: Bool) async -> RefreshResult {
        guard refreshState != .refreshing else { return .skipped }
        refreshState = .refreshing

        let existingSnapshot: WeatherSnapshot?
        if preservingLoadedState,
           case .loaded(let snapshot, _) = loadState {
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
            loadState = .loaded(snapshot: snapshot, plan: plan)
            await notifications.replaceNotifications(
                plan: plan,
                locationName: snapshot.locationName,
                enabled: preferences.alertsEnabled
            )
            scheduleBackgroundRefresh()
            refreshState = .idle
            return .succeeded
        } catch {
            if let cached = existingSnapshot ?? cache.load() {
                let plan = evaluator.plan(snapshot: cached, preferences: preferences)
                loadState = .loaded(snapshot: cached, plan: plan)
            } else {
                loadState = .failed(message: error.localizedDescription, cached: nil)
            }
            refreshState = .failed
            return .failed
        }
    }

    @discardableResult
    func refreshIfNeeded(now: Date = .now) async -> RefreshResult {
        guard hasCompletedOnboarding else { return .skipped }

        switch loadState {
        case .idle, .failed:
            return await refresh()
        case .loading:
            return .skipped
        case .loaded(let snapshot, _):
            guard now.timeIntervalSince(snapshot.fetchedAt) >= Self.foregroundRefreshInterval else {
                return .skipped
            }
            return await refresh(preservingLoadedState: true)
        }
    }

    func usePreviewWeather() async {
        let snapshot = WeatherSnapshot.preview
        let plan = evaluator.plan(snapshot: snapshot, preferences: preferences)
        refreshState = .idle
        loadState = .loaded(snapshot: snapshot, plan: plan)
    }

    func shouldShowStaleBanner(for snapshot: WeatherSnapshot, now: Date = .now) -> Bool {
        refreshState == .failed &&
            now.timeIntervalSince(snapshot.fetchedAt) > 60 * 60 * 3
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
        guard case .loaded(let snapshot, _) = loadState else { return }
        let plan = evaluator.plan(snapshot: snapshot, preferences: preferences)
        loadState = .loaded(snapshot: snapshot, plan: plan)
        Task {
            await notifications.replaceNotifications(
                plan: plan,
                locationName: snapshot.locationName,
                enabled: preferences.alertsEnabled
            )
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: String.backgroundRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger().debug("Failed to schedule background refresh: \(error)")
        }
    }
}
