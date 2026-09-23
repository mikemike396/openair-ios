import BackgroundTasks
import CoreLocation
import Foundation
import Observation
import OSLog
import UserNotifications
import UIKit

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
    let locationSelection: LocationSelectionModel
    private let evaluator: any RecommendationEvaluating
    private let notifications: any NotificationScheduling
    private let cache: WeatherCache
    private let widgetPublisher: any WidgetSnapshotPublishing
    private let appReviewManager: AppReviewManager
    private var userPreferences: any UserPreferenceStoring

    // View state
    var loadState: DashboardLoadState = .idle
    private(set) var refreshState: RefreshState = .idle
    private(set) var locationAuthorization: CLAuthorizationStatus
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var isRequestingNotificationPermission = false

    // Location lifecycle
    private var isForeground = false
    private var locationWork: Task<Void, Never>?
    private var foregroundCheckTask: Task<Void, Never>?
    private var locationBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var lastRoutineWeatherRequestAt: Date?
    private var stabilization: RecommendationStabilizationState
    private var pendingBackgroundFollowAuthorization = false
    private var backgroundAuthorizationFallbackTask: Task<Void, Never>?
    private(set) var showsBackgroundFollowPermissionAlert = false

    // Invalidates weather results when location selection or access changes.
    private var weatherContextVersion = 0
    // Invalidates a pending location choice only when another selection is made.
    // Permission changes must still allow that choice to report its error.
    private var locationSelectionVersion = 0

    // Refresh queue
    private enum RefreshLocationSource {
        case currentLocation
        case deliveredLocation(Coordinate)
        case savedLocation
    }

    private struct RefreshRequest {
        let keepsLoadedState: Bool
        let source: RefreshLocationSource
        let onlyIfNeeded: Bool
        let movementOnly: Bool
    }

    private var pendingRefresh: RefreshRequest?

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
            guard userPreferences.savedPlace != newValue else { return }
            userPreferences.savedPlace = newValue
            locationSelectionVersion += 1
            weatherContextVersion += 1
            pendingRefresh = nil
            stabilization = .init()
            userPreferences.recommendationStabilization = stabilization
            synchronizeLocationMonitoring()
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
            let previous = userPreferences.preferences
            userPreferences.preferences = newValue
            if previous != newValue {
                stabilization.resetForPreferenceChange()
                userPreferences.recommendationStabilization = stabilization
            }
            recalculate()
        }
    }

    var forecastRange: ForecastRange {
        get {
            userPreferences.forecastRange
        }
        set {
            userPreferences.forecastRange = newValue
        }
    }

    var followLocationInBackground: Bool {
        get {
            userPreferences.followLocationInBackground == true && locationAuthorization == .authorizedAlways
        }
        set {
            locationAuthorization = location.authorizationStatus
            if newValue && locationAuthorization != .authorizedAlways {
                userPreferences.followLocationInBackground = false
                if locationAuthorization == .authorizedWhenInUse &&
                    !userPreferences.hasRequestedAlwaysLocationAccess {
                    userPreferences.hasRequestedAlwaysLocationAccess = true
                    pendingBackgroundFollowAuthorization = true
                    showsBackgroundFollowPermissionAlert = false
                    location.requestAlwaysAuthorization()
                    backgroundAuthorizationFallbackTask?.cancel()
                    backgroundAuthorizationFallbackTask = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(2)) }
                        catch { return }
                        guard let self, self.pendingBackgroundFollowAuthorization,
                              UIApplication.shared.applicationState == .active else { return }
                        self.finishBackgroundFollowAuthorizationAttempt()
                        self.synchronizeLocationMonitoring()
                    }
                } else {
                    pendingBackgroundFollowAuthorization = false
                    backgroundAuthorizationFallbackTask?.cancel()
                    showsBackgroundFollowPermissionAlert = true
                }
                synchronizeLocationMonitoring()
                return
            }
            guard followLocationInBackground != newValue || pendingBackgroundFollowAuthorization || showsBackgroundFollowPermissionAlert else { return }
            pendingBackgroundFollowAuthorization = false
            backgroundAuthorizationFallbackTask?.cancel()
            showsBackgroundFollowPermissionAlert = false
            userPreferences.followLocationInBackground = newValue
            if !newValue {
                locationWork?.cancel()
                locationWork = nil
                weatherContextVersion += 1
                pendingRefresh = nil
                endLocationBackgroundTask()
            }
            synchronizeLocationMonitoring()
        }
    }

    init(
        weather: WeatherProviding = WeatherKitClient(),
        location: LocationProviding = LocationClient(),
        places: PlaceSearching = MapKitPlaceSearchClient(),
        evaluator: RecommendationEvaluating = RecommendationEngine(),
        notifications: NotificationScheduling = NotificationClient(),
        cache: WeatherCache = WeatherCache(),
        widgetPublisher: any WidgetSnapshotPublishing = DisabledWidgetSnapshotPublisher(),
        userPreferences: any UserPreferenceStoring,
        appReviewManager: AppReviewManager
    ) {
        self.weather = weather
        self.location = location
        self.locationAuthorization = location.authorizationStatus
        self.locationSelection = LocationSelectionModel(places: places)
        self.evaluator = evaluator
        self.notifications = notifications
        self.cache = cache
        self.widgetPublisher = widgetPublisher
        self.userPreferences = userPreferences
        self.stabilization = userPreferences.recommendationStabilization ?? .init()
        self.appReviewManager = appReviewManager
        if location.authorizationStatus == .authorizedAlways || userPreferences.followLocationInBackground == true {
            self.userPreferences.hasRequestedAlwaysLocationAccess = true
        }
        if userPreferences.followLocationInBackground == nil {
            self.userPreferences.followLocationInBackground = userPreferences.hasCompletedOnboarding &&
                location.authorizationStatus == .authorizedAlways
        } else if location.authorizationStatus != .authorizedAlways {
            self.userPreferences.followLocationInBackground = false
        }
        if hasCompletedOnboarding, let cached = cache.load() {
            let base = evaluator.plan(snapshot: cached, preferences: preferences)
            let plan = stabilization.plan(for: cached, base: base, preferences: preferences, fresh: false)
            self.userPreferences.recommendationStabilization = stabilization
            loadState = .loaded(snapshot: cached, plan: plan)
            lastRoutineWeatherRequestAt = cached.fetchedAt
        }
        location.onLocationChange = { [weak self] coordinate in
            self?.receiveLocation(coordinate)
        }
        location.onAuthorizationChange = { [weak self] status in
            self?.authorizationChanged(status)
        }
    }

    func dismissBackgroundFollowPermissionAlert() {
        showsBackgroundFollowPermissionAlert = false
    }

    var locationAccessBlocked: Bool {
        locationAuthorization == .denied || locationAuthorization == .restricted
    }

    // Called during application launch too, before any scene exists.
    func synchronizeLocationMonitoring() {
        location.setMonitoring(
            enabled: hasCompletedOnboarding && savedPlace == nil && followLocationInBackground,
            foreground: isForeground
        )
        foregroundCheckTask?.cancel()
        foregroundCheckTask = nil
        if isForeground && hasCompletedOnboarding && savedPlace == nil {
            foregroundCheckTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(15 * 60)) }
                    catch { return }
                    guard let self, !Task.isCancelled else { return }
                    _ = await self.checkForegroundLocation()
                }
            }
        }
    }

    func setForeground(_ foreground: Bool) {
        isForeground = foreground
        locationAuthorization = location.authorizationStatus
        if foreground && pendingBackgroundFollowAuthorization {
            finishBackgroundFollowAuthorizationAttempt()
        }
        if locationAuthorization != .authorizedAlways {
            userPreferences.followLocationInBackground = false
        }
        synchronizeLocationMonitoring()
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        locationAuthorization = status
        if pendingBackgroundFollowAuthorization && status == .authorizedAlways {
            pendingBackgroundFollowAuthorization = false
            backgroundAuthorizationFallbackTask?.cancel()
            showsBackgroundFollowPermissionAlert = false
            userPreferences.followLocationInBackground = true
        } else if status != .authorizedAlways {
            userPreferences.followLocationInBackground = false
        }
        if savedPlace == nil && (status == .denied || status == .restricted) {
            weatherContextVersion += 1
            pendingRefresh = nil
        }
        synchronizeLocationMonitoring()
    }

    private func finishBackgroundFollowAuthorizationAttempt() {
        guard pendingBackgroundFollowAuthorization else { return }
        pendingBackgroundFollowAuthorization = false
        backgroundAuthorizationFallbackTask?.cancel()
        locationAuthorization = location.authorizationStatus
        if locationAuthorization == .authorizedAlways {
            userPreferences.followLocationInBackground = true
            showsBackgroundFollowPermissionAlert = false
        } else {
            userPreferences.followLocationInBackground = false
            showsBackgroundFollowPermissionAlert = true
        }
    }

    @discardableResult
    func refreshOnActivation() async -> RefreshResult {
        setForeground(true)
        await refreshNotificationPermission()
        guard hasCompletedOnboarding else { return .skipped }
        if savedPlace != nil { return await refreshIfNeeded() }
        let result = await performRefresh(keepsLoadedState: true, onlyIfNeeded: true)
        if isForeground { recordSignificantEventIfNeeded(for: result) }
        return result
    }

    private func receiveLocation(_ coordinate: Coordinate) {
        guard !isForeground, hasCompletedOnboarding, savedPlace == nil,
              followLocationInBackground, locationAuthorization == .authorizedAlways else { return }
        if let lastRoutineWeatherRequestAt,
           Date.now.timeIntervalSince(lastRoutineWeatherRequestAt) < .foregroundRefreshInterval { return }
        // Hold a bounded execution allowance for geocoding, weather, and publishing.
        if locationBackgroundTask == .invalid {
            locationBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Update local weather") { [weak self] in
                Task { @MainActor in
                    self?.weatherContextVersion += 1
                    self?.pendingRefresh = nil
                    self?.locationWork?.cancel()
                    self?.endLocationBackgroundTask()
                }
            }
        }
        if refreshState == .refreshing {
            pendingRefresh = RefreshRequest(keepsLoadedState: true, source: .deliveredLocation(coordinate), onlyIfNeeded: true, movementOnly: false)
            return
        }
        locationWork = Task { [weak self] in
            guard let self else { return }
            _ = await refreshForLocation(coordinate)
            if refreshState != .refreshing { endLocationBackgroundTask() }
        }
    }

    private func endLocationBackgroundTask() {
        guard locationBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(locationBackgroundTask)
        locationBackgroundTask = .invalid
    }

    @discardableResult
    func refreshForLocation(_ coordinate: Coordinate) async -> RefreshResult {
        guard hasCompletedOnboarding, savedPlace == nil,
              locationAuthorization == .authorizedWhenInUse || locationAuthorization == .authorizedAlways else { return .skipped }
        return await performRefresh(keepsLoadedState: true, source: .deliveredLocation(coordinate), onlyIfNeeded: true)
    }

    @discardableResult
    func checkForegroundLocation() async -> RefreshResult {
        guard isForeground, hasCompletedOnboarding, savedPlace == nil else { return .skipped }
        do {
            let coordinate = try await location.requestLocation()
            return await performRefresh(
                keepsLoadedState: true,
                source: .deliveredLocation(coordinate),
                onlyIfNeeded: true,
                movementOnly: true
            )
        } catch {
            return .skipped
        }
    }

    @discardableResult
    func start() async -> RefreshResult {
        await refreshOnActivation()
    }

    func refreshNotificationPermission() async {
        let previousStatus = notificationStatus
        notificationStatus = await notifications.authorizationStatus()
        if notificationStatus != previousStatus,
           case .loaded(let snapshot, let plan) = loadState {
            await notifications.replaceNotifications(
                plan: plan, locationName: snapshot.locationName, enabled: preferences.alertsEnabled
            )
        }
    }

    func requestNotificationPermission() async {
        guard !isRequestingNotificationPermission else { return }
        isRequestingNotificationPermission = true
        defer { isRequestingNotificationPermission = false }
        await refreshNotificationPermission()
        if notificationStatus == .notDetermined {
            _ = try? await notifications.requestAuthorization()
        }
        await refreshNotificationPermission()
    }

    var notificationsAllowed: Bool {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    var alertsEffectivelyEnabled: Bool {
        preferences.alertsEnabled && notificationsAllowed
    }

    /// Keep the user's choice across the trip to Settings (and an app relaunch).
    /// The visible switch remains off until notification permission is granted.
    func enableAlertsWhenPermissionGranted() {
        var updated = preferences
        updated.alertsEnabled = true
        preferences = updated.normalized
    }

    @discardableResult
    func setAlertsEnabled(_ enabled: Bool) async -> Bool {
        if enabled { await requestNotificationPermission() }
        var updated = preferences
        updated.alertsEnabled = enabled && notificationsAllowed
        preferences = updated.normalized
        return updated.alertsEnabled
    }

    func completeOnboarding() async {
        hasCompletedOnboarding = true
        synchronizeLocationMonitoring()
        await refresh()
    }

    func choose(place: SavedPlace) {
        savedPlace = place
        locationSelection.clearSearchResults()
    }

    func chooseAndRefresh(place: SavedPlace) async {
        choose(place: place)
        guard hasCompletedOnboarding else { return }
        await refresh()
    }

    func useCurrentLocation() async -> Bool {
        guard locationSelection.beginCurrentLocation() else { return false }
        defer { locationSelection.endCurrentLocation() }
        let selectionVersion = locationSelectionVersion
        let coordinate: Coordinate
        do {
            // Keep the selected city until a usable location is available.
            coordinate = try await location.requestLocation()
            try Task.checkCancellation()
            guard selectionVersion == locationSelectionVersion else { return false }
            savedPlace = nil
            locationSelection.clearSearchResults()
        } catch {
            guard selectionVersion == locationSelectionVersion else { return false }
            locationSelection.showCurrentLocationError(error.localizedDescription)
            return false
        }
        guard hasCompletedOnboarding else {
            let name = await location.placename(for: coordinate) ?? "Current Location"
            lastKnownCurrentLocation = SavedPlace(name: name, coordinate: coordinate)
            return true
        }
        let committedSelectionVersion = locationSelectionVersion
        let result = await performRefresh(keepsLoadedState: true, source: .deliveredLocation(coordinate))
        guard committedSelectionVersion == locationSelectionVersion else { return false }
        if result == .failed {
            locationSelection.showCurrentLocationError(
                locationAuthorization == .denied || locationAuthorization == .restricted
                    ? LocationError.denied.localizedDescription : LocationError.unavailable.localizedDescription
            )
            return false
        }
        locationSelection.errorMessage = nil
        return true
    }

    /// Refreshes weather for the selected location.
    ///
    /// - Parameter keepsLoadedState: Whether to keep the current forecast visible while fetching.
    /// - Returns: The result of the refresh attempt.
    /// - Note: In automatic-location mode this requests a fresh foreground location.
    /// Use ``refreshForBackground()`` for background refreshes that must not touch Core Location.
    @discardableResult
    func refresh(keepsLoadedState: Bool = false) async -> RefreshResult {
        let result = await performRefresh(keepsLoadedState: keepsLoadedState)
        recordSignificantEventIfNeeded(for: result)
        return result
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
        await performRefresh(keepsLoadedState: true, source: .savedLocation)
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
        guard hasCompletedOnboarding, refreshState != .refreshing else { return .skipped }

        switch loadState {
        case .idle, .failed:
            return await refresh()
        case .loading:
            return .skipped
        case .loaded(let snapshot, _):
            guard now.timeIntervalSince(snapshot.fetchedAt) >= .foregroundRefreshInterval else {
                publishLoadedSnapshot()
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
        widgetPublisher.publish(weather: snapshot, plan: plan, preferences: preferences)
    }

    func shouldShowStaleBanner(for snapshot: WeatherSnapshot, now: Date = .now) -> Bool {
        refreshState == .failed &&
            now.timeIntervalSince(snapshot.fetchedAt) > .staleCacheInterval
    }

    @discardableResult
    private func performRefresh(
        keepsLoadedState: Bool,
        source: RefreshLocationSource = .currentLocation,
        onlyIfNeeded: Bool = false,
        movementOnly: Bool = false
    ) async -> RefreshResult {
        let request = RefreshRequest(
            keepsLoadedState: keepsLoadedState,
            source: source,
            onlyIfNeeded: onlyIfNeeded,
            movementOnly: movementOnly
        )
        guard refreshState != .refreshing else {
            // A scheduled fetch must not replace a newer movement event.
            switch source {
            case .savedLocation:
                if pendingRefresh == nil { pendingRefresh = request }
            case .currentLocation, .deliveredLocation:
                pendingRefresh = request
            }
            return .skipped
        }
        refreshState = .refreshing
        var next: RefreshRequest? = request
        var firstResult: RefreshResult?
        while let current = next {
            let result = await executeRefresh(current)
            if firstResult == nil { firstResult = result }
            next = Task.isCancelled ? nil : pendingRefresh
            pendingRefresh = nil
            refreshState = next != nil ? .refreshing : (result == .failed ? .failed : .idle)
        }
        scheduleBackgroundRefresh()
        endLocationBackgroundTask()
        return firstResult ?? .skipped
    }

    private func executeRefresh(_ request: RefreshRequest) async -> RefreshResult {
        let contextVersion = weatherContextVersion
        let existingSnapshot: WeatherSnapshot?
        if case .loaded(let snapshot, _) = loadState { existingSnapshot = snapshot }
        else { existingSnapshot = nil }
        if !request.keepsLoadedState || existingSnapshot == nil { loadState = .loading }
        defer {
            // A permission or mode change can invalidate a request before it publishes.
            // Never leave the dashboard stuck in that request's loading state.
            if case .loading = loadState {
                if let existingSnapshot {
                    loadState = .loaded(snapshot: existingSnapshot, plan: stabilizedPlan(for: existingSnapshot, fresh: false))
                } else if locationAuthorization == .denied || locationAuthorization == .restricted {
                    loadState = .failed(message: LocationError.denied.localizedDescription, cached: nil)
                } else {
                    loadState = .idle
                }
            }
        }

        do {
            guard let target = try await targetForWeatherRefresh(
                source: request.source,
                existingSnapshot: existingSnapshot,
                onlyIfNeeded: request.onlyIfNeeded,
                movementOnly: request.movementOnly
            )
            else { return .skipped }
            try Task.checkCancellation()
            guard contextVersion == weatherContextVersion else { return .skipped }
            lastRoutineWeatherRequestAt = .now
            let snapshot = try await weather.fetchWeather(for: target.coordinate, locationName: target.name)
            try Task.checkCancellation()
            guard contextVersion == weatherContextVersion else { return .skipped }
            let previousStatus = stabilization.effective?.status
            let plan = stabilizedPlan(for: snapshot, fresh: true)
            cache.save(snapshot)
            loadState = .loaded(snapshot: snapshot, plan: plan)
            widgetPublisher.publish(weather: snapshot, plan: plan, preferences: preferences)
            await notifications.replaceNotifications(
                plan: plan,
                locationName: snapshot.locationName,
                enabled: preferences.alertsEnabled
            )
            if !isForeground, preferences.alertsEnabled,
               let previousStatus, previousStatus != plan.current.status {
                await notifications.notifyCurrentChange(
                    status: plan.current.status,
                    locationName: snapshot.locationName
                )
            }
            return .succeeded
        } catch {
            guard contextVersion == weatherContextVersion else { return .skipped }
            if let cached = existingSnapshot ?? cache.load() {
                loadState = .loaded(snapshot: cached, plan: stabilizedPlan(for: cached, fresh: false))
            } else {
                loadState = .failed(message: error.localizedDescription, cached: nil)
            }
            return .failed
        }
    }

    private func recordSignificantEventIfNeeded(for result: RefreshResult) {
        guard result == .succeeded else { return }
        appReviewManager.recordSignificantEvent()
    }

    private func targetForWeatherRefresh(
        source: RefreshLocationSource,
        existingSnapshot: WeatherSnapshot?,
        onlyIfNeeded: Bool,
        movementOnly: Bool
    ) async throws -> (coordinate: Coordinate, name: String)? {
        // The user's selected city takes precedence over every automatic source.
        if let savedPlace {
            return (savedPlace.coordinate, savedPlace.name)
        }

        switch source {
        case .currentLocation:
            return try await resolveCurrentLocationTarget(
                existingSnapshot: existingSnapshot,
                onlyIfNeeded: onlyIfNeeded,
                movementOnly: movementOnly
            )
        case .deliveredLocation(let coordinate):
            return try await resolveCurrentLocationTarget(
                coordinate: coordinate,
                existingSnapshot: existingSnapshot,
                onlyIfNeeded: onlyIfNeeded,
                movementOnly: movementOnly
            )
        case .savedLocation:
            guard let lastKnownCurrentLocation else { return nil }
            return (lastKnownCurrentLocation.coordinate, lastKnownCurrentLocation.name)
        }
    }

    private func resolveCurrentLocationTarget(
        coordinate deliveredCoordinate: Coordinate? = nil,
        existingSnapshot: WeatherSnapshot?,
        onlyIfNeeded: Bool,
        movementOnly: Bool
    ) async throws -> (coordinate: Coordinate, name: String)? {
        let contextVersion = weatherContextVersion
        let coordinate: Coordinate
        if let deliveredCoordinate { coordinate = deliveredCoordinate }
        else { coordinate = try await location.requestLocation() }
        if onlyIfNeeded, let existingSnapshot {
            let distance = existingSnapshot.coordinate.clLocation.distance(from: coordinate.clLocation)
            if distance < 1_000 &&
                (movementOnly || Date.now.timeIntervalSince(existingSnapshot.fetchedAt) < .foregroundRefreshInterval) {
                lastKnownCurrentLocation = SavedPlace(
                    name: lastKnownCurrentLocation?.name ?? existingSnapshot.locationName,
                    coordinate: coordinate
                )
                publishLoadedSnapshot()
                return nil
            }
        }
        let name = await location.placename(for: coordinate) ?? "Current Location"
        try Task.checkCancellation()
        guard contextVersion == weatherContextVersion, savedPlace == nil else { throw CancellationError() }
        lastKnownCurrentLocation = SavedPlace(name: name, coordinate: coordinate)
        return (coordinate, name)
    }

    private func recalculate() {
        guard case .loaded(let snapshot, _) = loadState else { return }
        let plan = stabilizedPlan(for: snapshot, fresh: false)
        loadState = .loaded(snapshot: snapshot, plan: plan)
        widgetPublisher.publish(weather: snapshot, plan: plan, preferences: preferences)
        Task {
            await notifications.replaceNotifications(
                plan: plan,
                locationName: snapshot.locationName,
                enabled: preferences.alertsEnabled
            )
        }
    }

    private func stabilizedPlan(for snapshot: WeatherSnapshot, fresh: Bool) -> RecommendationPlan {
        let base = evaluator.plan(snapshot: snapshot, preferences: preferences)
        let plan = stabilization.plan(for: snapshot, base: base, preferences: preferences, fresh: fresh)
        userPreferences.recommendationStabilization = stabilization
        return plan
    }

    private func publishLoadedSnapshot() {
        guard case .loaded(let snapshot, let plan) = loadState else { return }
        widgetPublisher.publish(weather: snapshot, plan: plan, preferences: preferences)
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
