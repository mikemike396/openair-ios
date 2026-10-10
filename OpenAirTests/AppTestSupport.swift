import CoreLocation
import Testing
import UserNotifications
@testable import OpenAir

/// Composes real stores and coordinator with replaceable adapters; exposes no forwarding API.
@MainActor
final class AppTestFixture {
    let weatherStore: WeatherStore
    let locationStore: LocationStore
    let notificationStore: NotificationStore
    let userPreferences: any UserPreferenceStoring
    let coordinator: AppCoordinator
    let background = BackgroundRefreshSpy()

    init(
        weather: any WeatherProviding = PreviewWeatherClient(),
        location: any LocationProviding = LocationStub(result: .success(.init(latitude: 0, longitude: 0))),
        places: any PlaceSearching = PlaceSearchStub(),
        evaluator: any RecommendationEvaluating = RecommendationEngine(),
        notifications: any NotificationScheduling = NotificationStub(),
        cache: WeatherCache = WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "fixture-\(UUID()).json")),
        widgetPublisher: any WidgetSnapshotPublishing = DisabledWidgetSnapshotPublisher(),
        userPreferences: any UserPreferenceStoring,
        appReviewManager: AppReviewManager
    ) {
        self.userPreferences = userPreferences
        locationStore = LocationStore(provider: location, places: places, preferences: userPreferences)
        weatherStore = WeatherStore(
            requests: WeatherRequestCoordinator(weather: weather, location: location, preferences: userPreferences),
            evaluator: evaluator, cache: cache, widgets: widgetPublisher, preferences: userPreferences
        )
        notificationStore = NotificationStore(scheduler: notifications, preferences: userPreferences)
        coordinator = AppCoordinator(
            weather: weatherStore, location: locationStore, notifications: notificationStore,
            preferences: userPreferences, reviews: appReviewManager, background: background
        )
    }
}

final class BackgroundRefreshSpy: BackgroundRefreshManaging {
    private(set) var scheduleCount = 0
    private(set) var isRunning = false
    var expiration: (@MainActor () -> Void)?

    func beginLocationUpdate(expiration: @escaping @MainActor () -> Void) {
        guard !isRunning else { return }
        isRunning = true
        self.expiration = expiration
    }
    func endLocationUpdate() { isRunning = false }
    func scheduleRefresh() { scheduleCount += 1 }
}

func testWeatherSnapshot(fetchedAt: Date) -> WeatherSnapshot {
    let base = WeatherSnapshot.preview
    return WeatherSnapshot(
        locationName: base.locationName,
        coordinate: base.coordinate,
        fetchedAt: fetchedAt,
        current: base.current,
        hourly: base.hourly
    )
}
final class InMemoryUserPreferenceStore: UserPreferenceStoring {
    var hasCompletedOnboarding = false
    var savedPlace: SavedPlace?
    var lastKnownCurrentLocation: SavedPlace?
    var followLocationInBackground: Bool?
    var hasRequestedAlwaysLocationAccess = false
    var backgroundFollowTipState: BackgroundFollowTipState = .uninitialized
    var recommendationStabilization: RecommendationStabilizationState?
    var forecastRange = ForecastRange.tenDays
    var reviewSignificantEventCount = 0
    var lastReviewRequestAttemptAt: Date?
    private var storedPreferences: ComfortPreferences?

    var preferences: ComfortPreferences {
        get {
            storedPreferences ?? .default(for: Locale(identifier: "en_US"))
        }
        set {
            storedPreferences = newValue
        }
    }

    func applyDefaultPreferences(for locale: Locale) {
        if storedPreferences == nil {
            storedPreferences = .default(for: locale)
        }
    }
}
final class LocationStub: LocationProviding {
    var onLocationChange: ((Coordinate) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    private(set) var alwaysRequests = 0
    private(set) var monitoringEnabled = false
    private(set) var monitoringForeground = false
    var statusOverride: CLAuthorizationStatus?
    func requestAlwaysAuthorization() { alwaysRequests += 1 }
    func setMonitoring(enabled: Bool, foreground: Bool) {
        monitoringEnabled = enabled && authorizationStatus == .authorizedAlways
        monitoringForeground = foreground
    }

    var result: Result<Coordinate, any Error>
    let placename: String?
    var requestHandler: (() async throws -> Coordinate)?
    private(set) var requestLocationCount = 0
    private(set) var placenameCount = 0
    var authorizationStatus: CLAuthorizationStatus {
        if let statusOverride { return statusOverride }
        switch result {
        case .success: return .authorizedWhenInUse
        case .failure: return .denied
        }
    }

    init(result: Result<Coordinate, any Error>, placename: String? = nil) {
        self.result = result
        self.placename = placename
    }

    func requestAuthorization() {}
    func requestLocation() async throws -> Coordinate {
        requestLocationCount += 1
        if let requestHandler { return try await requestHandler() }
        return try result.get()
    }
    func placename(for coordinate: Coordinate) async -> String? {
        placenameCount += 1
        return placename
    }
}

struct PlaceSearchStub: PlaceSearching {
    func search(query: String) async throws -> [SavedPlace] { [] }
}
final class WidgetSnapshotPublisherSpy: WidgetSnapshotPublishing {
    private(set) var publishedLocationNames: [String] = []

    func publish(
        weather: WeatherSnapshot,
        plan: RecommendationPlan,
        preferences: ComfortPreferences
    ) {
        publishedLocationNames.append(weather.locationName)
    }
}

actor WeatherSpy: WeatherProviding {
    private let snapshots: [WeatherSnapshot]
    private(set) var fetchCount = 0

    init(snapshots: [WeatherSnapshot]) {
        self.snapshots = snapshots
    }

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        let snapshot = snapshots[min(fetchCount, snapshots.count - 1)]
        fetchCount += 1
        return await WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }
}

enum WeatherProviderError: Error {
    case unavailable
}

struct FailingWeatherProvider: WeatherProviding {
    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        throw WeatherProviderError.unavailable
    }
}

actor FailingThenSucceedingWeatherProvider: WeatherProviding {
    private let snapshot: WeatherSnapshot
    private var fetchCount = 0

    init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
    }

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        defer { fetchCount += 1 }
        guard fetchCount > 0 else {
            throw WeatherProviderError.unavailable
        }
        return await WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }
}

actor FailingThenSuspendedWeatherProvider: WeatherProviding {
    private var continuation: CheckedContinuation<WeatherSnapshot, any Error>?
    private var secondFetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var fetchCount = 0

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        fetchCount += 1
        guard fetchCount > 1 else {
            throw WeatherProviderError.unavailable
        }

        secondFetchStartedContinuation?.resume()
        secondFetchStartedContinuation = nil
        let snapshot = try await withCheckedThrowingContinuation { continuation = $0 }
        return await WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }

    func waitUntilSecondFetchStarts() async {
        guard fetchCount < 2 else { return }
        await withCheckedContinuation { secondFetchStartedContinuation = $0 }
    }

    func resume(returning snapshot: WeatherSnapshot) {
        continuation?.resume(returning: snapshot)
        continuation = nil
    }
}

actor SuspendedWeatherProvider: WeatherProviding {
    private var continuation: CheckedContinuation<WeatherSnapshot, any Error>?
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private(set) var fetchCount = 0

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        fetchCount += 1
        fetchStartedContinuation?.resume()
        fetchStartedContinuation = nil
        let snapshot = try await withCheckedThrowingContinuation { continuation = $0 }
        return await WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }

    func waitUntilFetchStarts() async {
        guard fetchCount == 0 else { return }
        await withCheckedContinuation { fetchStartedContinuation = $0 }
    }

    func resume(returning snapshot: WeatherSnapshot) {
        continuation?.resume(returning: snapshot)
        continuation = nil
    }

    func resume(throwing error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
struct NotificationStub: NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {}
}

final class TravelFixture {
    let preferences = InMemoryUserPreferenceStore()
    let location = LocationStub(result: .success(.init(latitude: 39.7391, longitude: -75.5398)), placename: "Travel city")
    let weather = TravelWeatherProvider()
    let widgets = WidgetSnapshotPublisherSpy()
    let notifications = TravelNotificationSpy()
    let store: AppTestFixture

    init(completedOnboarding: Bool = true, cachedSnapshot: WeatherSnapshot? = nil,
         authorization: CLAuthorizationStatus? = nil) {
        preferences.hasCompletedOnboarding = completedOnboarding
        location.statusOverride = authorization
        let cache = WeatherCache(url: FileManager.default.temporaryDirectory.appending(path: "travel-\(UUID()).json"))
        if let cachedSnapshot { cache.save(cachedSnapshot) }
        store = AppTestFixture(weather: weather, location: location, places: PlaceSearchStub(),
                         notifications: notifications,
                         cache: cache,
                         widgetPublisher: widgets, userPreferences: preferences,
                         appReviewManager: AppReviewManager(userPreferences: preferences))
    }

    var snapshot: WeatherSnapshot? {
        if case .loaded(let snapshot, _) = store.weatherStore.loadState { return snapshot }
        return nil
    }
}

@MainActor
final class TravelWeatherProvider: WeatherProviding {
    var coordinates: [Coordinate] = []
    var fetchCount: Int { coordinates.count }
    var suspendNext = false
    var fails = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var suspensionWaiter: CheckedContinuation<Void, Never>?

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        coordinates.append(coordinate)
        if suspendNext {
            suspendNext = false
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                suspensionWaiter?.resume()
                suspensionWaiter = nil
            }
        }
        if fails { throw WeatherProviderError.unavailable }
        let base = WeatherSnapshot.preview
        return WeatherSnapshot(locationName: locationName, coordinate: coordinate, fetchedAt: .now,
                               current: base.current, hourly: base.hourly)
    }

    func waitForSuspension() async {
        if continuation != nil { return }
        await withCheckedContinuation { suspensionWaiter = $0 }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

final class TravelNotificationSpy: NotificationScheduling {
    var names: [String] = []
    var plans: [RecommendationPlan] = []
    var enabledValues: [Bool] = []
    private var schedulingWaiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?
    var status: UNAuthorizationStatus = .authorized
    var requestedStatus: UNAuthorizationStatus = .authorized
    var requestCount = 0
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        status = requestedStatus
        return status == .authorized
    }
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {
        names.append(locationName)
        plans.append(plan)
        enabledValues.append(enabled)
        if let waiter = schedulingWaiter, names.count >= waiter.count {
            schedulingWaiter = nil
            waiter.continuation.resume()
        }
    }

    func waitForScheduling(count: Int) async {
        guard names.count < count else { return }
        await withCheckedContinuation { schedulingWaiter = (count, $0) }
    }
}


@MainActor
final class SuspendedLocationLookup {
    private var continuation: CheckedContinuation<Coordinate, any Error>?
    private var waiter: CheckedContinuation<Void, Never>?

    func request() async throws -> Coordinate {
        try await withCheckedThrowingContinuation {
            continuation = $0
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilRequested() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func finish(fails: Bool) {
        if fails { continuation?.resume(throwing: LocationError.unavailable) }
        else { continuation?.resume(returning: .init(latitude: 41, longitude: -82)) }
        continuation = nil
    }
}
