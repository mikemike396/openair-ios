import Foundation

struct ComfortPreferences: Codable, Sendable, Equatable {
    var idealMinimumFahrenheit: Double = .idealMinimumFahrenheit
    var idealMaximumFahrenheit: Double = .idealMaximumFahrenheit
    var maximumDewPointFahrenheit: Double = .maximumDewPointFahrenheit
    var maximumRainChance: Double = .maximumRainChance
    var maximumWindMPH: Double = .maximumWindMPH
    var alertsEnabled = true
    var temperatureUnit: TemperatureUnit = .fahrenheit

    static func `default`(for locale: Locale) -> ComfortPreferences {
        var preferences = ComfortPreferences()
        preferences.temperatureUnit = locale.measurementSystem == .us ? .fahrenheit : .celsius
        return preferences
    }
}
