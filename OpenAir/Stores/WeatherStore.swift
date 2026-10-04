import Foundation
import Observation

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

/// Owns the forecast state and serializes requests. Cross-feature effects are wired by AppCoordinator.
@Observable
@MainActor
final class WeatherStore {
    private let requests: WeatherRequestCoordinator
    private let evaluator: any RecommendationEvaluating
    private let cache: WeatherCache
    private let widgets: any WidgetSnapshotPublishing
    private let preferences: any UserPreferenceStoring
    private var stabilization: RecommendationStabilizationState
    private var contextVersion = 0
    private var pendingRefresh: RefreshRequest?

    private struct RefreshRequest {
        let keepsLoadedState: Bool
        let source: WeatherRequestCoordinator.Source
        let policy: WeatherRequestCoordinator.Policy
    }

    var loadState: DashboardLoadState = .idle
    private(set) var refreshState: RefreshState = .idle
    var lastRequestAt: Date? { requests.lastRequestAt }

    @ObservationIgnored var isLocationAccessBlocked: (() -> Bool)?
    @ObservationIgnored var onFreshForecast: ((WeatherSnapshot, RecommendationPlan, RecommendationStatus?, WeatherRequestCoordinator.Source) async -> Void)?
    @ObservationIgnored var onRecalculatedForecast: ((WeatherSnapshot, RecommendationPlan) async -> Void)?
    @ObservationIgnored var onRefreshQueueFinished: (() -> Void)?

    init(
        requests: WeatherRequestCoordinator,
        evaluator: any RecommendationEvaluating,
        cache: WeatherCache,
        widgets: any WidgetSnapshotPublishing,
        preferences: any UserPreferenceStoring
    ) {
        self.requests = requests
        self.evaluator = evaluator
        self.cache = cache
        self.widgets = widgets
        self.preferences = preferences
        stabilization = preferences.recommendationStabilization ?? .init()
        if preferences.hasCompletedOnboarding, let cached = cache.load() {
            loadState = .loaded(snapshot: cached, plan: stabilizedPlan(for: cached, fresh: false))
            requests.seedLastRequest(at: cached.fetchedAt)
        }
    }

    func invalidateContext(resetStabilization: Bool = false) {
        contextVersion += 1
        pendingRefresh = nil
        if resetStabilization {
            stabilization = .init()
            preferences.recommendationStabilization = stabilization
        }
    }

    /// Movement replaces older pending work; a scheduled refresh cannot replace pending movement.
    func enqueueLocation(_ coordinate: Coordinate) {
        pendingRefresh = RefreshRequest(keepsLoadedState: true, source: .deliveredLocation(coordinate), policy: .whenStaleOrMoved)
    }

    @discardableResult
    func refresh(
        keepsLoadedState: Bool = false,
        source: WeatherRequestCoordinator.Source = .currentLocation,
        policy: WeatherRequestCoordinator.Policy = .always
    ) async -> RefreshResult {
        let request = RefreshRequest(keepsLoadedState: keepsLoadedState, source: source, policy: policy)
        guard refreshState != .refreshing else {
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
        onRefreshQueueFinished?()
        return firstResult ?? .skipped
    }

    @discardableResult
    func refreshIfNeeded(now: Date = .now) async -> RefreshResult {
        guard preferences.hasCompletedOnboarding, refreshState != .refreshing else { return .skipped }
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
        let plan = evaluator.plan(snapshot: snapshot, preferences: preferences.preferences)
        refreshState = .idle
        loadState = .loaded(snapshot: snapshot, plan: plan)
        widgets.publish(weather: snapshot, plan: plan, preferences: preferences.preferences)
    }

    func shouldShowStaleBanner(for snapshot: WeatherSnapshot, now: Date = .now) -> Bool {
        refreshState == .failed && now.timeIntervalSince(snapshot.fetchedAt) > .staleCacheInterval
    }

    func preferencesChanged(resetStabilization: Bool) {
        if resetStabilization {
            stabilization.resetForPreferenceChange()
            preferences.recommendationStabilization = stabilization
        }
        guard case .loaded(let snapshot, _) = loadState else { return }
        let plan = stabilizedPlan(for: snapshot, fresh: false)
        loadState = .loaded(snapshot: snapshot, plan: plan)
        widgets.publish(weather: snapshot, plan: plan, preferences: preferences.preferences)
        Task { await onRecalculatedForecast?(snapshot, plan) }
    }

    private func executeRefresh(_ request: RefreshRequest) async -> RefreshResult {
        let version = contextVersion
        let existingSnapshot: WeatherSnapshot?
        if case .loaded(let snapshot, _) = loadState { existingSnapshot = snapshot }
        else { existingSnapshot = nil }
        if !request.keepsLoadedState || existingSnapshot == nil { loadState = .loading }
        defer {
            if case .loading = loadState {
                if let existingSnapshot {
                    loadState = .loaded(snapshot: existingSnapshot, plan: stabilizedPlan(for: existingSnapshot, fresh: false))
                } else if isLocationAccessBlocked?() == true {
                    loadState = .failed(message: LocationError.denied.localizedDescription, cached: nil)
                } else {
                    loadState = .idle
                }
            }
        }
        do {
            let resolution = try await requests.resolveTarget(.init(
                source: request.source,
                selectedPlace: preferences.savedPlace,
                existingSnapshot: existingSnapshot,
                policy: request.policy
            )) { [weak self] in
                guard let self else { return false }
                return version == self.contextVersion && self.preferences.savedPlace == nil
            }
            let target: WeatherRequestCoordinator.Target
            switch resolution {
            case .target(let resolvedTarget): target = resolvedTarget
            case .unchangedLocation:
                publishLoadedSnapshot()
                return .skipped
            case .noLastKnownLocation: return .skipped
            }
            try Task.checkCancellation()
            guard version == contextVersion else { return .skipped }
            let snapshot = try await requests.fetch(for: target)
            try Task.checkCancellation()
            guard version == contextVersion else { return .skipped }
            let previousStatus = stabilization.effective?.status
            let plan = stabilizedPlan(for: snapshot, fresh: true)
            cache.save(snapshot)
            loadState = .loaded(snapshot: snapshot, plan: plan)
            widgets.publish(weather: snapshot, plan: plan, preferences: preferences.preferences)
            await onFreshForecast?(snapshot, plan, previousStatus, request.source)
            return .succeeded
        } catch {
            guard version == contextVersion else { return .skipped }
            if let cached = existingSnapshot ?? cache.load() {
                loadState = .loaded(snapshot: cached, plan: stabilizedPlan(for: cached, fresh: false))
            } else {
                loadState = .failed(message: error.localizedDescription, cached: nil)
            }
            return .failed
        }
    }

    private func stabilizedPlan(for snapshot: WeatherSnapshot, fresh: Bool) -> RecommendationPlan {
        let base = evaluator.plan(snapshot: snapshot, preferences: preferences.preferences)
        let plan = stabilization.plan(for: snapshot, base: base, preferences: preferences.preferences, fresh: fresh)
        preferences.recommendationStabilization = stabilization
        return plan
    }

    private func publishLoadedSnapshot() {
        guard case .loaded(let snapshot, let plan) = loadState else { return }
        widgets.publish(weather: snapshot, plan: plan, preferences: preferences.preferences)
    }
}
