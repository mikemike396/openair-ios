import SwiftUI
import UIKit

struct LocationSettingsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    private var selection: LocationSelectionModel { store.locationSelection }

    var body: some View {
        Section {
            activeLocationRow

            if store.savedPlace != nil {
                currentLocationButton(title: "Use Current Location", loadingTitle: "Finding Location")
            } else {
                Toggle("Follow location in background", isOn: Binding(
                    get: { store.followLocationInBackground },
                    set: { store.followLocationInBackground = $0 }
                ))
            }

            if selection.errorSource == .currentLocation, let error = selection.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Weather Location")
        } footer: {
            if store.savedPlace == nil {
                Text(Self.followingFooter(isEnabled: store.followLocationInBackground))
            }
        }
        .alert("Background following is off", isPresented: Binding(
            get: { store.showsBackgroundFollowPermissionAlert },
            set: { if !$0 { store.dismissBackgroundFollowPermissionAlert() } }
        )) {
            Button("Not Now", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    store.enableBackgroundFollowingAfterSettings()
                    openURL(url)
                }
            }
        } message: {
            Text("Allow Always location access in Settings. If granted, background following turns on when you return.")
        }

        Section("Choose a City") {
            TextField("Search to switch to a city", text: $query)
                .onSubmit { Task { await selection.searchPlaces(query) } }
                .task(id: query) {
                    await selection.searchPlaces(query, debounce: true)
                }

            if selection.errorSource == .citySearch, let error = selection.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            ForEach(selection.searchResults.prefix(4)) { place in
                Button(place.name) {
                    Task {
                        query = ""
                        await store.chooseAndRefresh(place: place)
                    }
                }
            }
        }
    }

    static func followingFooter(isEnabled: Bool) -> String {
        if isEnabled {
            "OpenAir can follow significant location changes in the background and refresh weather and alerts. iOS controls when updates arrive."
        } else {
            "When off, OpenAir checks location while in use and when reopened. Background weather and alerts use the last known place."
        }
    }

    private var activeLocationRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.savedPlace?.name ?? "Current Location")
                Text(store.savedPlace == nil ? currentLocationName : "Selected City")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            store.savedPlace.map { "Active weather location: selected city, \($0.name)" }
                ?? "Active weather location: current location, \(currentLocationName)"
        )
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
        if let lastKnownCurrentLocation = store.lastKnownCurrentLocation {
            return lastKnownCurrentLocation.name
        }
        guard case .loaded(let snapshot, _) = store.loadState else {
            return "Current location"
        }
        return snapshot.locationName
    }

    private func chooseCurrentLocation() async {
        _ = await store.useCurrentLocation()
    }
}
