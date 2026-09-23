import CoreLocation
import Foundation
import Observation
import UIKit

/// Owns the location-following permission, monitoring, and foreground check timer.
@Observable
@MainActor
final class LocationFollowController {
    private let location: any LocationProviding
    private let preferences: any UserPreferenceStoring
    private var isEligible = false
    private var pendingAlwaysAuthorization = false
    private var authorizationFallbackTask: Task<Void, Never>?
    private var foregroundCheckTask: Task<Void, Never>?

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isForeground = false
    private(set) var showsPermissionAlert = false

    @ObservationIgnored var onSignificantLocation: ((Coordinate) -> Void)?
    @ObservationIgnored var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    @ObservationIgnored var onForegroundCheck: (() async -> Void)?

    var isFollowing: Bool {
        preferences.followLocationInBackground == true && authorizationStatus == .authorizedAlways
    }

    init(location: any LocationProviding, preferences: any UserPreferenceStoring) {
        self.location = location
        self.preferences = preferences
        authorizationStatus = location.authorizationStatus

        if authorizationStatus == .authorizedAlways || preferences.followLocationInBackground == true {
            self.preferences.hasRequestedAlwaysLocationAccess = true
        }
        if preferences.followLocationInBackground == nil {
            self.preferences.followLocationInBackground = preferences.hasCompletedOnboarding &&
                authorizationStatus == .authorizedAlways
        } else if authorizationStatus != .authorizedAlways {
            self.preferences.followLocationInBackground = false
        }

        location.onLocationChange = { [weak self] coordinate in
            self?.onSignificantLocation?(coordinate)
        }
        location.onAuthorizationChange = { [weak self] status in
            self?.authorizationChanged(status)
        }
    }

    func setEligible(_ eligible: Bool) {
        isEligible = eligible
        synchronizeMonitoring()
    }

    func setForeground(_ foreground: Bool, eligible: Bool) {
        isForeground = foreground
        isEligible = eligible
        authorizationStatus = location.authorizationStatus
        if foreground && pendingAlwaysAuthorization {
            finishAlwaysAuthorizationAttempt()
        }
        if foreground && authorizationStatus != .authorizedAlways {
            preferences.followLocationInBackground = false
        }
        synchronizeMonitoring()
    }

    /// Returns true when stopping following should invalidate pending location weather.
    @discardableResult
    func setFollowing(_ enabled: Bool) -> Bool {
        authorizationStatus = location.authorizationStatus
        if enabled && authorizationStatus != .authorizedAlways {
            preferences.followLocationInBackground = false
            if authorizationStatus == .authorizedWhenInUse &&
                !preferences.hasRequestedAlwaysLocationAccess {
                preferences.hasRequestedAlwaysLocationAccess = true
                pendingAlwaysAuthorization = true
                showsPermissionAlert = false
                location.requestAlwaysAuthorization()
                authorizationFallbackTask?.cancel()
                authorizationFallbackTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(2)) }
                    catch { return }
                    guard let self, self.pendingAlwaysAuthorization,
                          UIApplication.shared.applicationState == .active else { return }
                    self.finishAlwaysAuthorizationAttempt()
                    self.synchronizeMonitoring()
                }
            } else {
                pendingAlwaysAuthorization = false
                authorizationFallbackTask?.cancel()
                showsPermissionAlert = true
            }
            synchronizeMonitoring()
            return false
        }
        guard isFollowing != enabled || pendingAlwaysAuthorization || showsPermissionAlert else { return false }
        pendingAlwaysAuthorization = false
        authorizationFallbackTask?.cancel()
        showsPermissionAlert = false
        preferences.followLocationInBackground = enabled
        synchronizeMonitoring()
        return !enabled
    }

    func dismissPermissionAlert() {
        showsPermissionAlert = false
    }

    /// Remember the user's explicit Settings handoff without showing the switch as on yet.
    func enableFollowingAfterSettings() {
        preferences.followLocationInBackground = true
        synchronizeMonitoring()
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        if pendingAlwaysAuthorization && status == .authorizedAlways {
            pendingAlwaysAuthorization = false
            authorizationFallbackTask?.cancel()
            showsPermissionAlert = false
            preferences.followLocationInBackground = true
        } else if status != .authorizedAlways {
            preferences.followLocationInBackground = false
        }
        onAuthorizationChange?(status)
        synchronizeMonitoring()
    }

    private func finishAlwaysAuthorizationAttempt() {
        guard pendingAlwaysAuthorization else { return }
        pendingAlwaysAuthorization = false
        authorizationFallbackTask?.cancel()
        authorizationStatus = location.authorizationStatus
        if authorizationStatus == .authorizedAlways {
            preferences.followLocationInBackground = true
            showsPermissionAlert = false
        } else {
            preferences.followLocationInBackground = false
            showsPermissionAlert = true
        }
    }

    private func synchronizeMonitoring() {
        location.setMonitoring(enabled: isEligible && isFollowing, foreground: isForeground)
        foregroundCheckTask?.cancel()
        foregroundCheckTask = nil
        if isForeground && isEligible {
            foregroundCheckTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(15 * 60)) }
                    catch { return }
                    guard let self, !Task.isCancelled else { return }
                    await self.onForegroundCheck?()
                }
            }
        }
    }
}
