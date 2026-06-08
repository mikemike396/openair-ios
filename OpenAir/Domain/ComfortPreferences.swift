import Foundation

struct ComfortPreferences: Codable, Sendable, Equatable {
    var idealMinimumFahrenheit: Double = .defaultIdealMinimumFahrenheit
    var idealMaximumFahrenheit: Double = .defaultIdealMaximumFahrenheit
    var maximumDewPointFahrenheit: Double = .defaultMaximumDewPointFahrenheit
    var maximumRainChance: Double = .defaultMaximumRainChance
    var maximumWindMPH: Double = .defaultMaximumWindMPH
    var alertsEnabled = true
    var temperatureUnit: TemperatureUnit = .fahrenheit

    static func `default`(for locale: Locale) -> ComfortPreferences {
        var preferences = ComfortPreferences()
        preferences.temperatureUnit = locale.measurementSystem == .us ? .fahrenheit : .celsius
        return preferences
    }

    mutating func resetSliderDefaults(for locale: Locale) {
        let defaults = Self.default(for: locale)
        idealMinimumFahrenheit = defaults.idealMinimumFahrenheit
        idealMaximumFahrenheit = defaults.idealMaximumFahrenheit
        maximumDewPointFahrenheit = defaults.maximumDewPointFahrenheit
        maximumRainChance = defaults.maximumRainChance
        maximumWindMPH = defaults.maximumWindMPH
    }

    var normalized: ComfortPreferences {
        var preferences = self
        if preferences.idealMinimumFahrenheit > preferences.idealMaximumFahrenheit {
            preferences.idealMaximumFahrenheit = preferences.idealMinimumFahrenheit
        }
        return preferences
    }
}
