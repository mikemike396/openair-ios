import Foundation

/// Connects feature stores and owns cross-feature work, without observable presentation state.
final class AppCoordinator {
    private let weather: WeatherStore
    private let location: LocationStore
    private let notifications: NotificationStore
    private let preferences: any UserPreferenceStoring
    private let reviews: AppReviewManager
    private let background: any BackgroundRefreshManaging
    private var locationWork: Task<Void, Never>?

    init(
        weather: WeatherStore,
        location: LocationStore,
        notifications: NotificationStore,
        preferences: any UserPreferenceStoring,
        reviews: AppReviewManager,
        background: any BackgroundRefreshManaging
    ) {
        self.weather = weather
        self.location = location
        self.notifications = notifications
        self.preferences = preferences
        self.reviews = reviews
        self.background = background
        wireStores()
    }

    private func wireStores() {
        location.onContextInvalidated = { [weak self] reset in
            self?.weather.invalidateContext(resetStabilization: reset)
        }
        location.onFollowingStopped = { [weak self] in
            self?.locationWork?.cancel()
            self?.locationWork = nil
            self?.background.endLocationUpdate()
        }
        location.onSignificantLocation = { [weak self] in self?.receiveLocation($0) }
        location.onForegroundCheck = { [weak self] in _ = await self?.checkForegroundLocation() }
        weather.isLocationAccessBlocked = { [weak self] in self?.location.locationAccessBlocked ?? false }
        weather.onFreshForecast = { [weak self] snapshot, plan, previous, source in
            guard let self else { return }
            await self.notifications.synchronize(plan: plan, locationName: snapshot.locationName)
            self.location.recordTravel(for: snapshot, source: source)
            if !self.location.isForeground, let previous, previous != plan.current.status {
                await self.notifications.notifyCurrentChange(status: plan.current.status, locationName: snapshot.locationName)
            }
        }
        weather.onRecalculatedForecast = { [weak self] snapshot, plan in
            await self?.notifications.synchronize(plan: plan, locationName: snapshot.locationName)
        }
        weather.onRefreshQueueFinished = { [weak self] in
            self?.background.scheduleRefresh()
            self?.background.endLocationUpdate()
        }
        notifications.onAuthorizationChanged = { [weak self] in
            guard let self, case .loaded(let snapshot, let plan) = self.weather.loadState else { return }
            await self.notifications.synchronize(plan: plan, locationName: snapshot.locationName)
        }
        notifications.onPreferencesChanged = { [weak self] in self?.updatePreferences($0) }
    }

    func updatePreferences(_ updated: ComfortPreferences) {
        let changed = preferences.preferences != updated
        preferences.preferences = updated
        weather.preferencesChanged(resetStabilization: changed)
    }

    func synchronizeLocationMonitoring() { location.synchronizeLocationMonitoring() }
    func setForeground(_ foreground: Bool) { location.setForeground(foreground) }

    @discardableResult
    func refreshOnActivation() async -> RefreshResult {
        location.setForeground(true)
        await notifications.refreshPermission()
        guard preferences.hasCompletedOnboarding else { return .skipped }
        if location.savedPlace != nil { return await refreshIfNeeded() }
        let result = await weather.refresh(keepsLoadedState: true, policy: .whenStaleOrMoved)
        location.showPendingTravelTip()
        if location.isForeground { recordReviewEvent(for: result) }
        return result
    }

    @discardableResult
    func refresh(keepsLoadedState: Bool = false) async -> RefreshResult {
        let result = await weather.refresh(keepsLoadedState: keepsLoadedState)
        recordReviewEvent(for: result)
        return result
    }

    @discardableResult
    func refreshIfNeeded(now: Date = .now) async -> RefreshResult {
        let result = await weather.refreshIfNeeded(now: now)
        recordReviewEvent(for: result)
        return result
    }

    /// Uses the selected city or last known current location; never requests a foreground fix.
    @discardableResult
    func refreshForBackground() async -> RefreshResult {
        await weather.refresh(keepsLoadedState: true, source: .savedLocation)
    }

    @discardableResult
    func refreshForLocation(_ coordinate: Coordinate) async -> RefreshResult {
        guard preferences.hasCompletedOnboarding, location.savedPlace == nil,
              location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways else { return .skipped }
        return await weather.refresh(keepsLoadedState: true, source: .deliveredLocation(coordinate), policy: .whenStaleOrMoved)
    }

    @discardableResult
    func checkForegroundLocation() async -> RefreshResult {
        guard location.isForeground, preferences.hasCompletedOnboarding, location.savedPlace == nil else { return .skipped }
        do {
            let coordinate = try await location.requestLocation()
            return await weather.refresh(keepsLoadedState: true, source: .deliveredLocation(coordinate), policy: .whenMoved)
        } catch { return .skipped }
    }

    func completeOnboarding() async {
        preferences.hasCompletedOnboarding = true
        location.synchronizeLocationMonitoring()
        await refresh()
    }

    func chooseAndRefresh(place: SavedPlace) async {
        location.choose(place: place)
        guard preferences.hasCompletedOnboarding else { return }
        await refresh()
    }

    func useCurrentLocation() async -> Bool {
        let selection = location.selection
        guard selection.beginCurrentLocation() else { return false }
        defer { selection.endCurrentLocation() }
        let version = location.selectionVersion
        let coordinate: Coordinate
        do {
            coordinate = try await location.requestLocation()
            try Task.checkCancellation()
            guard version == location.selectionVersion else { return false }
            location.savedPlace = nil
            selection.clearSearchResults()
        } catch {
            guard version == location.selectionVersion else { return false }
            selection.showCurrentLocationError(error.localizedDescription)
            return false
        }
        guard preferences.hasCompletedOnboarding else {
            await location.rememberCurrentLocation(coordinate)
            return true
        }
        let committedVersion = location.selectionVersion
        let result = await weather.refresh(keepsLoadedState: true, source: .deliveredLocation(coordinate))
        guard committedVersion == location.selectionVersion else { return false }
        if result == .failed {
            selection.showCurrentLocationError(location.locationAccessBlocked
                ? LocationError.denied.localizedDescription : LocationError.unavailable.localizedDescription)
            return false
        }
        selection.errorMessage = nil
        return true
    }

    private func receiveLocation(_ coordinate: Coordinate) {
        guard !location.isForeground, preferences.hasCompletedOnboarding, location.savedPlace == nil,
              location.followLocationInBackground, location.authorizationStatus == .authorizedAlways else { return }
        if let lastRequestAt = weather.lastRequestAt,
           Date.now.timeIntervalSince(lastRequestAt) < .foregroundRefreshInterval { return }
        background.beginLocationUpdate { [weak self] in
            self?.weather.invalidateContext()
            self?.locationWork?.cancel()
            self?.background.endLocationUpdate()
        }
        if weather.refreshState == .refreshing {
            weather.enqueueLocation(coordinate)
            return
        }
        locationWork = Task { [weak self] in
            guard let self else { return }
            _ = await self.refreshForLocation(coordinate)
            if self.weather.refreshState != .refreshing { self.background.endLocationUpdate() }
        }
    }

    private func recordReviewEvent(for result: RefreshResult) {
        if result == .succeeded { reviews.recordSignificantEvent() }
    }
}
