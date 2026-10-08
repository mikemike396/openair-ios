import SwiftUI

struct ComfortSettingsSection: View {
    @Environment(\.userPreferenceStore) private var preferenceStore
    @AppCoordinatorEnvironment private var coordinator
    @State private var showsResetConfirmation = false

    var body: some View {
        Section("Comfort range") {
            Picker("Temperature unit", selection: preferenceBinding(\.temperatureUnit)) {
                ForEach(TemperatureUnit.allCases) { unit in
                    Text(unit == .fahrenheit ? "Fahrenheit" : "Celsius").tag(unit)
                }
            }

            Picker("Temperature source", selection: preferenceBinding(\.temperatureEvaluationSource)) {
                ForEach(TemperatureEvaluationSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }

            temperatureSlider(
                title: "Minimum temperature",
                keyPath: \.idealMinimumFahrenheit,
                range: .minimumConfigurableTemperatureFahrenheit...(.maximumConfigurableIdealMinimumFahrenheit)
            )
            temperatureSlider(
                title: "Maximum temperature",
                keyPath: \.idealMaximumFahrenheit,
                range: .minimumConfigurableIdealMaximumFahrenheit...(.maximumConfigurableTemperatureFahrenheit)
            )
            temperatureSlider(
                title: "Maximum dew point",
                keyPath: \.maximumDewPointFahrenheit,
                range: .minimumConfigurableDewPointFahrenheit...(.maximumConfigurableDewPointFahrenheit)
            )
            valueSlider(
                title: "Maximum rain chance",
                keyPath: \.maximumRainChance,
                range: .minimumConfigurableRainChance...(.maximumConfigurableRainChance),
                step: 0.05,
                value: { $0.formatted(.percent) }
            )
            valueSlider(
                title: "Maximum sustained wind",
                keyPath: \.maximumWindMPH,
                range: .minimumConfigurableWindMPH...(.maximumConfigurableWindMPH),
                step: 1,
                value: { "\(Int($0)) mph" }
            )
            valueSlider(
                title: "Maximum gusts",
                keyPath: \.maximumGustMPH,
                range: .minimumConfigurableGustMPH...(.maximumConfigurableGustMPH),
                step: 1,
                value: { "\(Int($0)) mph" }
            )

            Button("Reset Comfort Defaults") {
                showsResetConfirmation = true
            }
        }
        .alert("Reset comfort settings?", isPresented: $showsResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                var preferences = preferenceStore.preferences
                preferences.resetSliderDefaults(for: .autoupdatingCurrent)
                coordinator.updatePreferences(preferences.normalized)
            }
        } message: {
            Text("Restore default comfort limits and temperature source. Your temperature unit, location, and alert settings won’t change.")
        }
    }

    private func temperatureSlider(
        title: String,
        keyPath: WritableKeyPath<ComfortPreferences, Double>,
        range: ClosedRange<Double>
    ) -> some View {
        let unit = preferenceStore.preferences.temperatureUnit
        return valueSlider(
            title: title,
            binding: temperaturePreferenceBinding(keyPath),
            currentValue: preferenceStore.preferences[keyPath: keyPath],
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
        valueSlider(
            title: title,
            binding: preferenceBinding(keyPath),
            currentValue: preferenceStore.preferences[keyPath: keyPath],
            range: range,
            step: step,
            value: value
        )
    }

    private func valueSlider(
        title: String,
        binding: Binding<Double>,
        currentValue: Double,
        range: ClosedRange<Double>,
        step: Double,
        value: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(value(currentValue))
                    .foregroundStyle(.secondary)
            }
            Slider(value: binding, in: range, step: step)
        }
    }

    private func preferenceBinding<Value>(
        _ keyPath: WritableKeyPath<ComfortPreferences, Value>
    ) -> Binding<Value> {
        Binding {
            preferenceStore.preferences[keyPath: keyPath]
        } set: { value in
            var preferences = preferenceStore.preferences
            preferences[keyPath: keyPath] = value
            coordinator.updatePreferences(preferences.normalized)
        }
    }

    private func temperaturePreferenceBinding(
        _ keyPath: WritableKeyPath<ComfortPreferences, Double>
    ) -> Binding<Double> {
        Binding {
            preferenceStore.preferences[keyPath: keyPath]
        } set: { value in
            var preferences = preferenceStore.preferences
            preferences[keyPath: keyPath] = value
            if keyPath == \.idealMinimumFahrenheit,
               preferences.idealMinimumFahrenheit > preferences.idealMaximumFahrenheit {
                preferences.idealMaximumFahrenheit = preferences.idealMinimumFahrenheit
            } else if keyPath == \.idealMaximumFahrenheit,
                      preferences.idealMaximumFahrenheit < preferences.idealMinimumFahrenheit {
                preferences.idealMinimumFahrenheit = preferences.idealMaximumFahrenheit
            }
            coordinator.updatePreferences(preferences)
        }
    }
}
