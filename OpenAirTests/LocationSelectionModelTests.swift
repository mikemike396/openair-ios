import Foundation
import Testing
@testable import OpenAir

@MainActor
struct LocationSelectionModelTests {
    @Test
    func searchAllowsCurrentLocationAndOnlyNewestResultsPublish() async {
        let places = SuspendedPlaceSearch()
        let model = LocationSelectionModel(places: places)
        let old = Task { await model.searchPlaces("Old") }
        await places.waitForRequest("Old")
        #expect(model.isSearching)
        #expect(model.beginCurrentLocation())
        model.endCurrentLocation()
        let newest = Task { await model.searchPlaces("Newest") }
        await places.waitForRequest("Newest")
        places.finish("Old")
        await old.value
        #expect(model.isSearching)
        #expect(model.searchResults.isEmpty)
        places.finish("Newest")
        await newest.value
        #expect(model.searchResults.map(\.name) == ["Newest"])
        #expect(model.canUseCurrentLocation)
    }

    @Test
    func currentLocationAllowsSearchButBlocksRepeatedSelection() async {
        let places = SuspendedPlaceSearch()
        let model = LocationSelectionModel(places: places)
        #expect(model.beginCurrentLocation())
        #expect(!model.beginCurrentLocation())
        let search = Task { await model.searchPlaces("City") }
        await places.waitForRequest("City")
        #expect(model.isChoosingCurrentLocation)
        places.finish("City")
        await search.value
        #expect(model.searchResults.map(\.name) == ["City"])
        model.endCurrentLocation()
        #expect(model.canUseCurrentLocation)
    }

    @Test
    func clearingSearchInvalidatesInFlightResults() async {
        let places = SuspendedPlaceSearch()
        let model = LocationSelectionModel(places: places)
        let search = Task { await model.searchPlaces("Old") }
        await places.waitForRequest("Old")
        model.clearSearchResults()
        #expect(model.beginCurrentLocation())
        places.finish("Old")
        await search.value
        #expect(model.searchResults.isEmpty)
        #expect(model.isChoosingCurrentLocation)
    }

    @Test
    func cancellingDebounceUnlocksCurrentLocation() async {
        let places = SuspendedPlaceSearch()
        let model = LocationSelectionModel(places: places)
        let search = Task { await model.searchPlaces("City", debounce: true) }
        await Task.yield()
        search.cancel()
        await search.value
        #expect(model.canUseCurrentLocation)
        #expect(model.errorMessage == nil)
        #expect(places.requests.isEmpty)
    }
}

@MainActor
private final class SuspendedPlaceSearch: PlaceSearching {
    var requests: [String] = []
    private var continuations: [String: CheckedContinuation<[SavedPlace], Never>] = [:]
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]

    func search(query: String) async throws -> [SavedPlace] {
        requests.append(query)
        return await withCheckedContinuation {
            continuations[query] = $0
            waiters.removeValue(forKey: query)?.resume()
        }
    }

    func waitForRequest(_ query: String) async {
        if continuations[query] != nil { return }
        await withCheckedContinuation { waiters[query] = $0 }
    }

    func finish(_ query: String) {
        continuations.removeValue(forKey: query)?.resume(returning: [
            SavedPlace(name: query, coordinate: .init(latitude: 41, longitude: -82))
        ])
    }
}
