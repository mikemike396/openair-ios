import CoreLocation
import Foundation
@preconcurrency import MapKit

protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var onLocationChange: ((Coordinate) -> Void)? { get set }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    func requestAuthorization()
    func requestAlwaysAuthorization()
    func setMonitoring(enabled: Bool, foreground: Bool)
    func requestLocation() async throws -> Coordinate
    func placename(for coordinate: Coordinate) async -> String?
}

enum LocationError: LocalizedError {
    case unavailable
    case denied

    var errorDescription: String? {
        switch self {
        case .unavailable: "Your location is temporarily unavailable."
        case .denied: "Location access is off. Choose a city instead."
        }
    }
}

final class LocationClient: NSObject, LocationProviding, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let requestManager = CLLocationManager()
    private var continuation: CheckedContinuation<Coordinate, any Error>?
    private var requestID: UUID?
    private var timeout: Task<Void, Never>?
    private var monitoringEnabled = false
    private var foreground = false
    private var significantChanges = false
    private var latestFixDate = Date.distantPast
    var onLocationChange: ((Coordinate) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        requestManager.delegate = self
        requestManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestAuthorization() { manager.requestWhenInUseAuthorization() }

    func requestAlwaysAuthorization() {
        guard authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestAlwaysAuthorization()
    }

    func setMonitoring(enabled: Bool, foreground: Bool) {
        let stopped = (monitoringEnabled && !enabled) || (self.foreground && !foreground)
        monitoringEnabled = enabled
        self.foreground = foreground
        updateMonitoring()
        if stopped {
            finishRequest(.failure(CancellationError()))
        }
    }

    private func updateMonitoring() {
        let shouldMonitor = monitoringEnabled && authorizationStatus == .authorizedAlways
            && CLLocationManager.significantLocationChangeMonitoringAvailable()
        if shouldMonitor != significantChanges {
            significantChanges = shouldMonitor
            if shouldMonitor { manager.startMonitoringSignificantLocationChanges() }
            else { manager.stopMonitoringSignificantLocationChanges() }
        }
    }

    func requestLocation() async throws -> Coordinate {
        guard authorizationStatus != .denied, authorizationStatus != .restricted else {
            throw LocationError.denied
        }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                finishRequest(.failure(CancellationError()))
                requestID = id
                self.continuation = continuation
                if authorizationStatus == .notDetermined {
                    manager.requestWhenInUseAuthorization()
                } else {
                    requestManager.requestLocation()
                }
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(20)) }
                    catch { return }
                    guard self?.requestID == id else { return }
                    self?.finishRequest(.failure(LocationError.unavailable))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.requestID == id else { return }
                self?.finishRequest(.failure(CancellationError()))
            }
        }
    }

    private func finishRequest(_ result: Result<Coordinate, any Error>) {
        let pending = continuation
        continuation = nil
        requestID = nil
        timeout?.cancel()
        timeout = nil
        if pending != nil { requestManager.stopUpdatingLocation() }
        pending?.resume(with: result)
    }

    func placename(for coordinate: Coordinate) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: coordinate.clLocation),
              let mapItem = try? await request.mapItems.first else { return nil }
        return mapItem.addressRepresentations?.cityWithContext(.short)
            ?? mapItem.addressRepresentations?.cityName
            ?? mapItem.address?.shortAddress
            ?? mapItem.address?.fullAddress
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager === self.manager {
            updateMonitoring()
            onAuthorizationChange?(authorizationStatus)
        }
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            if continuation != nil { requestManager.requestLocation() }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            finishRequest(.failure(LocationError.denied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Cached or invalid fixes must not move the forecast back to a previous town.
        guard let location = locations.last(where: {
            $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) <= 300
                && $0.timestamp >= latestFixDate
        }) else { return }
        latestFixDate = location.timestamp
        let coordinate = Coordinate(location.coordinate)
        if manager === requestManager {
            finishRequest(.success(coordinate))
        } else if continuation == nil && monitoringEnabled
                    && (authorizationStatus == .authorizedAlways || (foreground && authorizationStatus == .authorizedWhenInUse)) {
            onLocationChange?(coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        if (error as? CLError)?.code == .locationUnknown { return }
        if manager === requestManager { finishRequest(.failure(error)) }
    }
}
