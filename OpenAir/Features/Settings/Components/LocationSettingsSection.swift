import SwiftUI
import UIKit

struct LocationSettingsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    @State private var isChoosingCurrentLocation = false

    var body: some View {
        Section("Location") {
            if let place = store.savedPlace {
                LabeledContent("Selected city", value: place.name)
                currentLocationButton(title: "Use Current Location", loadingTitle: "Finding Location")
            } else {
                LabeledContent("Current city", value: currentLocationName)
                currentLocationButton(title: "Refresh Current Location", loadingTitle: "Refreshing Location")
            }

            if store.needsAlwaysLocationNotice {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Background location is off", systemImage: "location.slash")
                        .font(.subheadline.weight(.semibold))
                    Text("Allow location access Always to keep weather updated as you travel, even when OpenAir is closed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }

            if isChoosingCurrentLocation {
                ProgressView()
            }

            if let searchError = store.searchError {
                Text(searchError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            TextField("Search another city", text: $query)
                .onSubmit { Task { await store.searchPlaces(query) } }
                .task(id: query) {
                    await store.searchPlacesAfterDebounce(query)
                }

            ForEach(store.searchResults.prefix(4)) { place in
                Button(place.name) {
                    Task {
                        query = ""
                        await store.chooseAndRefresh(place: place)
                    }
                }
            }
        }
    }

    private func currentLocationButton(title: String, loadingTitle: String) -> some View {
        Button {
            Task { await chooseCurrentLocation() }
        } label: {
            Label(
                isChoosingCurrentLocation ? loadingTitle : title,
                systemImage: "location.fill"
            )
        }
        .disabled(isChoosingCurrentLocation)
    }

    private var currentLocationName: String {
        guard case .loaded(let snapshot, _) = store.loadState else {
            return "Current location"
        }
        return snapshot.locationName
    }

    private func chooseCurrentLocation() async {
        isChoosingCurrentLocation = true
        _ = await store.useCurrentLocation()
        isChoosingCurrentLocation = false
    }
}
