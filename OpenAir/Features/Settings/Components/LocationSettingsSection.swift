import SwiftUI
import UIKit

struct LocationSettingsSection: View {
    @Environment(LocationStore.self) private var location
    @Environment(WeatherStore.self) private var weather
    @AppCoordinatorEnvironment private var coordinator
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    private var selection: LocationSelectionModel { location.selection }

    var body: some View {
        Section {
            activeLocationRow

            if location.savedPlace != nil {
                currentLocationButton(title: "Use Current Location", loadingTitle: "Finding Location")
            } else {
                Toggle("Follow location in background", isOn: Binding(
                    get: { location.followLocationInBackground },
                    set: { location.followLocationInBackground = $0 }
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
            if location.savedPlace == nil {
                Text(Self.followingFooter(isEnabled: location.followLocationInBackground))
            }
        }
        .alert("Background following is off", isPresented: Binding(
            get: { location.showsBackgroundFollowPermissionAlert },
            set: { if !$0 { location.dismissBackgroundFollowPermissionAlert() } }
        )) {
            Button("Not Now", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    location.enableBackgroundFollowingAfterSettings()
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
                        await coordinator.chooseAndRefresh(place: place)
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
                Text(location.savedPlace?.name ?? "Current Location")
                Text(location.savedPlace == nil ? currentLocationName : "Selected City")
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
            location.savedPlace.map { "Active weather location: selected city, \($0.name)" }
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
        if let lastKnownCurrentLocation = location.lastKnownCurrentLocation {
            return lastKnownCurrentLocation.name
        }
        guard case .loaded(let snapshot, _) = weather.loadState else {
            return "Current location"
        }
        return snapshot.locationName
    }

    private func chooseCurrentLocation() async {
        _ = await coordinator.useCurrentLocation()
    }
}
