import SwiftUI
import UIKit

struct LocationSettingsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    private var selection: LocationSelectionModel { store.locationSelection }

    var body: some View {
        Section("Location") {
            if let place = store.savedPlace {
                LabeledContent("Selected city", value: place.name)
                currentLocationButton(title: "Use Current Location", loadingTitle: "Finding Location")
            } else {
                LabeledContent("Current city", value: currentLocationName)
                currentLocationButton(title: "Refresh Current Location", loadingTitle: "Refreshing Location")
            }

            if let searchError = selection.errorMessage {
                Text(searchError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            TextField("Search for a city", text: $query)
                .onSubmit { Task { await selection.searchPlaces(query) } }
                .task(id: query) {
                    await selection.searchPlaces(query, debounce: true)
                }

            ForEach(selection.searchResults.prefix(4)) { place in
                Button(place.name) {
                    Task {
                        query = ""
                        await store.chooseAndRefresh(place: place)
                    }
                }
            }

            if store.needsAlwaysLocationNotice || (store.locationAccessBlocked && (store.savedPlace == nil || selection.errorMessage != nil)) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(store.locationAccessBlocked ? "Location access is off" : "Update weather in the background")
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                    Text(store.locationAccessBlocked
                         ? "Allow location access in Settings to use your current location, or search for a city above."
                         : "Allow location access Always to keep weather updated as you travel, even when OpenAir is closed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
        }
    }

    private func currentLocationButton(title: String, loadingTitle: String) -> some View {
        Button {
            Task { await chooseCurrentLocation() }
        } label: {
            HStack {
                Label(
                    selection.isChoosingCurrentLocation ? loadingTitle : title,
                    systemImage: "location.fill"
                )
                Spacer()
                if selection.isChoosingCurrentLocation {
                    ProgressView()
                        .tint(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(!selection.canUseCurrentLocation)
    }

    private var currentLocationName: String {
        guard case .loaded(let snapshot, _) = store.loadState else {
            return "Current location"
        }
        return snapshot.locationName
    }

    private func chooseCurrentLocation() async {
        _ = await store.useCurrentLocation()
    }
}
