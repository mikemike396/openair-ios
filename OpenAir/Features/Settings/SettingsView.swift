import CoreLocation
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var isChoosingCurrentLocation = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Location") {
                    if let place = store.savedPlace {
                        LabeledContent("Selected city", value: place.name)
                        Button {
                            Task { await chooseCurrentLocation() }
                        } label: {
                            if isChoosingCurrentLocation {
                                Label("Finding Location", systemImage: "location.fill")
                            } else {
                                Label("Use Current Location", systemImage: "location.fill")
                            }
                        }
                        .disabled(isChoosingCurrentLocation)
                    } else {
                        LabeledContent("Current city", value: currentLocationName)
                        Button {
                            Task { await chooseCurrentLocation() }
                        } label: {
                            if isChoosingCurrentLocation {
                                Label("Refreshing Location", systemImage: "location.fill")
                            } else {
                                Label("Refresh Current Location", systemImage: "location.fill")
                            }
                        }
                        .disabled(isChoosingCurrentLocation)
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
                            await searchAfterDebounce()
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

                Section("Comfort range") {
                    Picker("Temperature unit", selection: preferenceBinding(\.temperatureUnit)) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit == .fahrenheit ? "Fahrenheit" : "Celsius").tag(unit)
                        }
                    }
                    temperatureSlider(
                        title: "Ideal minimum",
                        keyPath: \.idealMinimumFahrenheit,
                        range: 45...70
                    )
                    temperatureSlider(
                        title: "Ideal maximum",
                        keyPath: \.idealMaximumFahrenheit,
                        range: 65...85
                    )
                    temperatureSlider(
                        title: "Maximum dew point",
                        keyPath: \.maximumDewPointFahrenheit,
                        range: 45...68
                    )
                    valueSlider(
                        title: "Maximum rain chance",
                        keyPath: \.maximumRainChance,
                        range: 0.05...0.75,
                        step: 0.05,
                        value: { $0.formatted(.percent) }
                    )
                    valueSlider(
                        title: "Maximum sustained wind",
                        keyPath: \.maximumWindMPH,
                        range: 5...24,
                        step: 1,
                        value: { "\(Int($0)) mph" }
                    )
                }

                Section("Alerts") {
                    Toggle("Open and close alerts", isOn: preferenceBinding(\.alertsEnabled))
                    LabeledContent("Permission", value: notificationLabel)
                    Text("Alerts use the latest downloaded forecast. iOS may delay or skip background refreshes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Text("Weather data provided by Apple Weather.")
                    Text("OpenAir uses outdoor conditions only. It does not measure indoor temperature, humidity, air quality, or safety hazards.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func temperatureSlider(
        title: String,
        keyPath: WritableKeyPath<ComfortPreferences, Double>,
        range: ClosedRange<Double>
    ) -> some View {
        let unit = store.preferences.temperatureUnit
        return valueSlider(
            title: title,
            keyPath: keyPath,
            range: range,
            step: 1,
            value: { "\(unit.display($0))\(unit.symbol)" }
        )
    }

    private func valueSlider(
        title: String,
        keyPath: WritableKeyPath<ComfortPreferences, Double>,
        range: ClosedRange<Double>,
        step: Double,
        value: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(value(store.preferences[keyPath: keyPath]))
                    .foregroundStyle(.secondary)
            }
            Slider(value: preferenceBinding(keyPath), in: range, step: step)
        }
    }

    private func preferenceBinding<Value>(
        _ keyPath: WritableKeyPath<ComfortPreferences, Value>
    ) -> Binding<Value> {
        Binding {
            store.preferences[keyPath: keyPath]
        } set: { value in
            var preferences = store.preferences
            preferences[keyPath: keyPath] = value
            store.preferences = preferences
        }
    }

    private var notificationLabel: String {
        switch store.notificationStatus {
        case .authorized, .provisional, .ephemeral: "Allowed"
        case .denied: "Denied"
        default: "Not requested"
        }
    }

    private var currentLocationName: String {
        guard case .loaded(let snapshot, _, _) = store.loadState else {
            return "Current location"
        }
        return snapshot.locationName
    }

    private func searchAfterDebounce() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            store.clearSearchResults()
            return
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await store.searchPlaces(trimmedQuery)
    }

    private func chooseCurrentLocation() async {
        isChoosingCurrentLocation = true
        _ = await store.useCurrentLocation()
        isChoosingCurrentLocation = false
    }
}
