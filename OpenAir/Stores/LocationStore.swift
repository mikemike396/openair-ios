import CoreLocation
import Foundation
import Observation

@Observable
@MainActor
final class LocationStore {
    private let provider: any LocationProviding
    private let follow: LocationFollowController
    private let preferences: any UserPreferenceStoring
    let selection: LocationSelectionModel
    private(set) var selectionVersion = 0
    private var travelTipVisible = false

    @ObservationIgnored var onContextInvalidated: ((_ resetStabilization: Bool) -> Void)?
    @ObservationIgnored var onFollowingStopped: (() -> Void)?
    @ObservationIgnored var onSignificantLocation: ((Coordinate) -> Void)?
    @ObservationIgnored var onForegroundCheck: (() async -> Void)?

    var authorizationStatus: CLAuthorizationStatus { follow.authorizationStatus }
    var isForeground: Bool { follow.isForeground }
    var showsBackgroundFollowPermissionAlert: Bool { follow.showsPermissionAlert }
    var locationAccessBlocked: Bool { authorizationStatus == .denied || authorizationStatus == .restricted }
    var lastKnownCurrentLocation: SavedPlace? { preferences.lastKnownCurrentLocation }

    var savedPlace: SavedPlace? {
        get { preferences.savedPlace }
        set {
            guard preferences.savedPlace != newValue else { return }
            preferences.savedPlace = newValue
            if newValue != nil {
                if preferences.backgroundFollowTipState != .consumed {
                    preferences.backgroundFollowTipState = .uninitialized
                }
                travelTipVisible = false
            }
            selectionVersion += 1
            onContextInvalidated?(true)
            synchronizeLocationMonitoring()
        }
    }

    var followLocationInBackground: Bool {
        get { follow.isFollowing }
        set {
            if newValue { dismissBackgroundFollowTip() }
            if follow.setFollowing(newValue) {
                onContextInvalidated?(false)
                onFollowingStopped?()
            }
        }
    }

    var showsBackgroundFollowTip: Bool { travelTipVisible && canDisplayBackgroundFollowTip }
    private var canDisplayBackgroundFollowTip: Bool {
        preferences.hasCompletedOnboarding && savedPlace == nil &&
            authorizationStatus == .authorizedWhenInUse && !followLocationInBackground &&
            !preferences.hasRequestedAlwaysLocationAccess
    }
    private var canSuggestBackgroundFollowing: Bool {
        canDisplayBackgroundFollowTip && preferences.backgroundFollowTipState != .consumed
    }

    init(provider: any LocationProviding, places: any PlaceSearching, preferences: any UserPreferenceStoring) {
        self.provider = provider
        self.preferences = preferences
        follow = LocationFollowController(location: provider, preferences: preferences)
        selection = LocationSelectionModel(places: places)
        if preferences.savedPlace == nil, preferences.backgroundFollowTipState == .uninitialized,
           let coordinate = preferences.lastKnownCurrentLocation?.coordinate {
            preferences.backgroundFollowTipState = .tracking(coordinate)
        }
        follow.onSignificantLocation = { [weak self] in self?.onSignificantLocation?($0) }
        follow.onAuthorizationChange = { [weak self] status in
            guard let self else { return }
            if self.savedPlace == nil && (status == .denied || status == .restricted) {
                self.onContextInvalidated?(false)
            }
        }
        follow.onForegroundCheck = { [weak self] in await self?.onForegroundCheck?() }
    }

    func synchronizeLocationMonitoring() {
        follow.setEligible(preferences.hasCompletedOnboarding && savedPlace == nil)
    }

    func setForeground(_ foreground: Bool) {
        if !foreground { travelTipVisible = false }
        follow.setForeground(foreground, eligible: preferences.hasCompletedOnboarding && savedPlace == nil)
    }

    func requestLocation() async throws -> Coordinate { try await provider.requestLocation() }
    func rememberCurrentLocation(_ coordinate: Coordinate) async {
        let name = await provider.placename(for: coordinate) ?? "Current Location"
        preferences.lastKnownCurrentLocation = SavedPlace(name: name, coordinate: coordinate)
    }

    func choose(place: SavedPlace) {
        savedPlace = place
        selection.clearSearchResults()
    }

    func dismissBackgroundFollowPermissionAlert() { follow.dismissPermissionAlert() }
    func enableBackgroundFollowingAfterSettings() { follow.enableFollowingAfterSettings() }
    func dismissBackgroundFollowTip() {
        preferences.backgroundFollowTipState = .consumed
        travelTipVisible = false
    }

    func showPendingTravelTip() {
        if isForeground && !travelTipVisible && preferences.backgroundFollowTipState == .pending && canSuggestBackgroundFollowing {
            travelTipVisible = true
        }
    }

    func recordTravel(for snapshot: WeatherSnapshot, source: WeatherRequestCoordinator.Source) {
        guard canSuggestBackgroundFollowing else { return }
        switch source {
        case .currentLocation, .deliveredLocation:
            switch preferences.backgroundFollowTipState {
            case .tracking(let origin):
                if isForeground && origin.clLocation.distance(from: snapshot.coordinate.clLocation) >= 5_000 {
                    preferences.backgroundFollowTipState = .pending
                }
            case .uninitialized: preferences.backgroundFollowTipState = .tracking(snapshot.coordinate)
            case .pending, .consumed: break
            }
        case .savedLocation: break
        }
    }
}
