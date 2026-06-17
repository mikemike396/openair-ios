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

    var lastKnownCurrentLocation: SavedPlace? {
        get {
            userPreferences.lastKnownCurrentLocation
        }
        set {
            userPreferences.lastKnownCurrentLocation = newValue
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
            _ = try await resolveCurrentLocationTarget()
            searchError = nil
            if hasCompletedOnboarding {
                await performRefresh(keepsLoadedState: false, updateLocation: false)
            }
            return true
        } catch {
            searchError = error.localizedDescription
            return false
        }
    }

    /// Refreshes weather for the selected location.
    ///
    /// - Parameter keepsLoadedState: Whether to keep the current forecast visible while fetching.
    /// - Returns: The result of the refresh attempt.
    /// - Note: In automatic-location mode this requests a fresh foreground location.
    /// Use ``refreshForBackground()`` for background refreshes that must not touch Core Location.
    @discardableResult
    func refresh(keepsLoadedState: Bool = false) async -> RefreshResult {
        await performRefresh(keepsLoadedState: keepsLoadedState)
    }

    /// Refreshes weather for a background app refresh task.
    ///
    /// - Returns: The result of the background refresh attempt.
    /// - Note: This method never requests Core Location.
    ///   - In manual-location mode it uses ``savedPlace``.
    ///   - In automatic-location mode it uses ``lastKnownCurrentLocation``
    ///   - If no last-known current location exists, the refresh is skipped successfully.
    @discardableResult
    func refreshForBackground() async -> RefreshResult {
        await performRefresh(keepsLoadedState: true, updateLocation: false)
    }
    
    /// Refreshes weather only when the current loaded forecast is old enough.
    ///
    /// - Parameter now: The reference date used to decide whether the loaded forecast is stale enough to refresh.
    /// - Returns: The result of the refresh decision or attempt.
    /// - Note: This method skips when onboarding is incomplete, a refresh is already loading,
    /// or the loaded forecast is newer than the foreground refresh interval. When it
    /// does refresh loaded data, it keeps the current forecast visible while fetching.
    @discardableResult
    func refreshIfNeeded(now: Date = .now) async -> RefreshResult {
        guard hasCompletedOnboarding else { return .skipped }

        switch loadState {
        case .idle, .failed:
            return await refresh()
        case .loading:
            return .skipped
        case .loaded(let snapshot, _):
            guard now.timeIntervalSince(snapshot.fetchedAt) >= .foregroundRefreshInterval else {
                return .skipped
            }
            return await refresh(keepsLoadedState: true)
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
            now.timeIntervalSince(snapshot.fetchedAt) > .staleCacheInterval
    }

    @discardableResult
    private func performRefresh(keepsLoadedState: Bool, updateLocation: Bool = true) async -> RefreshResult {
        guard refreshState != .refreshing else { return .skipped }
        refreshState = .refreshing

        let existingSnapshot: WeatherSnapshot?
        if keepsLoadedState,
           case .loaded(let snapshot, _) = loadState {
            existingSnapshot = snapshot
        } else {
            existingSnapshot = nil
            loadState = .loading
        }

        do {
            guard let target = try await targetForWeatherRefresh(updateLocation: updateLocation)
            else {
                scheduleBackgroundRefresh()
                refreshState = .idle
                return .skipped
            }
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
            scheduleBackgroundRefresh()
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

    private func targetForWeatherRefresh(updateLocation: Bool) async throws -> (coordinate: Coordinate, name: String)? {
        if let savedPlace {
            return (savedPlace.coordinate, savedPlace.name)
        }
        
        guard updateLocation
        else {
            guard let lastKnownCurrentLocation else { return nil }
            return (lastKnownCurrentLocation.coordinate, lastKnownCurrentLocation.name)
        }
        return try await resolveCurrentLocationTarget()
    }

    private func resolveCurrentLocationTarget() async throws -> (coordinate: Coordinate, name: String) {
        let coordinate = try await location.requestLocation()
        let name = await location.placename(for: coordinate) ?? "Current Location"
        lastKnownCurrentLocation = SavedPlace(name: name, coordinate: coordinate)
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
        request.earliestBeginDate = Date(timeIntervalSinceNow: .backgroundRefreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger().debug("Failed to schedule background refresh: \(error)")
        }
    }
}
