import CoreLocation
import Foundation

/// Checks weather-request eligibility before reverse geocoding, then fetches weather.
@MainActor
final class WeatherRequestCoordinator {
    enum Source {
        case currentLocation
        case deliveredLocation(Coordinate)
        case savedLocation
    }

    enum Policy {
        /// Fetch even when the current weather is recent and the location is unchanged.
        case always
        /// Fetch when weather is at least 15 minutes old or the location moved at least 1 km.
        case whenStaleOrMoved
        /// Foreground periodic checks fetch only after moving at least 1 km.
        case whenMoved
    }

    struct Request {
        let source: Source
        let selectedPlace: SavedPlace?
        let existingSnapshot: WeatherSnapshot?
        let policy: Policy
    }

    struct Target {
        let coordinate: Coordinate
        let name: String
    }

    enum Resolution {
        case target(Target)
        case unchangedLocation
        case noLastKnownLocation
    }

    private let weather: any WeatherProviding
    private let location: any LocationProviding
    private let preferences: any UserPreferenceStoring
    private(set) var lastRequestAt: Date?

    init(
        weather: any WeatherProviding,
        location: any LocationProviding,
        preferences: any UserPreferenceStoring
    ) {
        self.weather = weather
        self.location = location
        self.preferences = preferences
    }

    func seedLastRequest(at date: Date) {
        lastRequestAt = date
    }

    func resolveTarget(_ request: Request, isContextCurrent: () -> Bool) async throws -> Resolution {
        // A manually selected city takes precedence over every automatic source.
        if let selectedPlace = request.selectedPlace {
            return .target(Target(coordinate: selectedPlace.coordinate, name: selectedPlace.name))
        }

        switch request.source {
        case .currentLocation:
            return try await resolveCurrentLocation(
                request: request,
                isContextCurrent: isContextCurrent
            )
        case .deliveredLocation(let coordinate):
            return try await resolveCurrentLocation(
                deliveredCoordinate: coordinate,
                request: request,
                isContextCurrent: isContextCurrent
            )
        case .savedLocation:
            guard let place = preferences.lastKnownCurrentLocation else {
                return .noLastKnownLocation
            }
            return .target(Target(coordinate: place.coordinate, name: place.name))
        }
    }

    func fetch(for target: Target) async throws -> WeatherSnapshot {
        lastRequestAt = .now
        return try await weather.fetchWeather(for: target.coordinate, locationName: target.name)
    }

    private func resolveCurrentLocation(
        deliveredCoordinate: Coordinate? = nil,
        request: Request,
        isContextCurrent: () -> Bool
    ) async throws -> Resolution {
        let coordinate: Coordinate
        if let deliveredCoordinate { coordinate = deliveredCoordinate }
        else { coordinate = try await location.requestLocation() }
        if let existingSnapshot = request.existingSnapshot {
            let distance = existingSnapshot.coordinate.clLocation.distance(from: coordinate.clLocation)
            let shouldSkip: Bool
            switch request.policy {
            case .always:
                shouldSkip = false
            case .whenStaleOrMoved:
                shouldSkip = distance < 1_000 &&
                    Date.now.timeIntervalSince(existingSnapshot.fetchedAt) < .foregroundRefreshInterval
            case .whenMoved:
                shouldSkip = distance < 1_000
            }
            if shouldSkip {
                preferences.lastKnownCurrentLocation = SavedPlace(
                    name: preferences.lastKnownCurrentLocation?.name ?? existingSnapshot.locationName,
                    coordinate: coordinate
                )
                return .unchangedLocation
            }
        }
        let name = await location.placename(for: coordinate) ?? "Current Location"
        try Task.checkCancellation()
        guard isContextCurrent() else { throw CancellationError() }
        preferences.lastKnownCurrentLocation = SavedPlace(name: name, coordinate: coordinate)
        return .target(Target(coordinate: coordinate, name: name))
    }
}
