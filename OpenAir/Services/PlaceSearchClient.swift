import Foundation
import MapKit

protocol PlaceSearching: Sendable {
    func search(query: String) async throws -> [SavedPlace]
}

struct MapKitPlaceSearchClient: PlaceSearching {
    func search(query: String) async throws -> [SavedPlace] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(8).compactMap { item in
            guard let name = item.addressRepresentations?.cityWithContext ?? item.name,
                  !name.isEmpty else { return nil }
            return SavedPlace(name: name, coordinate: Coordinate(item.location.coordinate))
        }
        .uniqued()
    }
}

private extension Array where Element == SavedPlace {
    func uniqued() -> [SavedPlace] {
        reduce(into: []) { result, place in
            if !result.contains(where: { $0.name == place.name }) {
                result.append(place)
            }
        }
    }
}
