import SwiftUI

struct ComfortSettingsSection: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Section("Comfort range") {
            Picker("Temperature unit", selection: preferenceBinding(\.temperatureUnit)) {
                ForEach(TemperatureUnit.allCases) { unit in
                    Text(unit == .fahrenheit ? "Fahrenheit" : "Celsius").tag(unit)
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
                var preferences = store.preferences
                preferences.resetSliderDefaults(for: .autoupdatingCurrent)
                store.preferences = preferences.normalized
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
            binding: temperaturePreferenceBinding(keyPath),
            currentValue: store.preferences[keyPath: keyPath],
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
            currentValue: store.preferences[keyPath: keyPath],
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
            store.preferences[keyPath: keyPath]
        } set: { value in
            var preferences = store.preferences
            preferences[keyPath: keyPath] = value
            store.preferences = preferences.normalized
        }
    }

    private func temperaturePreferenceBinding(
        _ keyPath: WritableKeyPath<ComfortPreferences, Double>
    ) -> Binding<Double> {
        Binding {
            store.preferences[keyPath: keyPath]
        } set: { value in
            var preferences = store.preferences
            preferences[keyPath: keyPath] = value
            if keyPath == \.idealMinimumFahrenheit,
               preferences.idealMinimumFahrenheit > preferences.idealMaximumFahrenheit {
                preferences.idealMaximumFahrenheit = preferences.idealMinimumFahrenheit
            } else if keyPath == \.idealMaximumFahrenheit,
                      preferences.idealMaximumFahrenheit < preferences.idealMinimumFahrenheit {
                preferences.idealMinimumFahrenheit = preferences.idealMaximumFahrenheit
            }
            store.preferences = preferences
        }
    }
}
