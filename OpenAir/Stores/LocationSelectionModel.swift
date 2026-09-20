import Foundation
import Observation

/// Shared search and selection state for onboarding and Location settings.
@Observable
final class LocationSelectionModel {
    private let places: any PlaceSearching
    private var searchID = UUID()
    private(set) var searchResults: [SavedPlace] = []
    private(set) var isSearching = false
    private(set) var isChoosingCurrentLocation = false
    var errorMessage: String?

    init(places: any PlaceSearching) {
        self.places = places
    }

    var canUseCurrentLocation: Bool { !isChoosingCurrentLocation }

    func beginCurrentLocation() -> Bool {
        guard canUseCurrentLocation else { return false }
        isChoosingCurrentLocation = true
        errorMessage = nil
        return true
    }

    func endCurrentLocation() {
        isChoosingCurrentLocation = false
    }

    func clearSearchResults() {
        searchID = UUID()
        isSearching = false
        searchResults = []
        errorMessage = nil
    }

    func searchPlaces(_ query: String, debounce: Bool = false) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        clearSearchResults()
        guard query.count >= (debounce ? 2 : 1) else { return }
        let id = searchID
        isSearching = true
        defer { if searchID == id { isSearching = false } }
        do {
            if debounce { try await Task.sleep(for: .milliseconds(300)) }
            try Task.checkCancellation()
            let results = try await places.search(query: query)
            try Task.checkCancellation()
            guard searchID == id else { return }
            searchResults = results
        } catch is CancellationError {
            return
        } catch {
            guard searchID == id else { return }
            errorMessage = error.localizedDescription
        }
    }
}
