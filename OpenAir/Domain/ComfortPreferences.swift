import Foundation

struct ComfortPreferences: Codable, Sendable, Equatable {
    var idealMinimumFahrenheit: Double = .defaultIdealMinimumFahrenheit
    var idealMaximumFahrenheit: Double = .defaultIdealMaximumFahrenheit
    var maximumDewPointFahrenheit: Double = .defaultMaximumDewPointFahrenheit
    var maximumRainChance: Double = .defaultMaximumRainChance
    var maximumWindMPH: Double = .defaultMaximumWindMPH
    var maximumGustMPH: Double = .defaultMaximumGustMPH
    var alertsEnabled = true
    var temperatureUnit: TemperatureUnit = .fahrenheit
    var temperatureEvaluationSource: TemperatureEvaluationSource = .feelsLike

    private enum CodingKeys: String, CodingKey {
        case idealMinimumFahrenheit
        case idealMaximumFahrenheit
        case maximumDewPointFahrenheit
        case maximumRainChance
        case maximumWindMPH
        case maximumGustMPH
        case alertsEnabled
        case temperatureUnit
        case temperatureEvaluationSource
    }

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
        maximumGustMPH = defaults.maximumGustMPH
        temperatureEvaluationSource = defaults.temperatureEvaluationSource
    }

    var normalized: ComfortPreferences {
        var preferences = self
        preferences.idealMinimumFahrenheit = min(
            max(preferences.idealMinimumFahrenheit, .minimumConfigurableTemperatureFahrenheit),
            .maximumConfigurableIdealMinimumFahrenheit
        )
        preferences.idealMaximumFahrenheit = min(
            max(preferences.idealMaximumFahrenheit, .minimumConfigurableIdealMaximumFahrenheit),
            .maximumConfigurableTemperatureFahrenheit
        )
        if preferences.idealMinimumFahrenheit > preferences.idealMaximumFahrenheit {
            preferences.idealMaximumFahrenheit = preferences.idealMinimumFahrenheit
        }
        preferences.maximumDewPointFahrenheit = min(
            max(preferences.maximumDewPointFahrenheit, .minimumConfigurableDewPointFahrenheit),
            .maximumConfigurableDewPointFahrenheit
        )
        preferences.maximumRainChance = min(
            max(preferences.maximumRainChance, .minimumConfigurableRainChance),
            .maximumConfigurableRainChance
        )
        preferences.maximumWindMPH = min(
            max(preferences.maximumWindMPH, .minimumConfigurableWindMPH),
            .maximumConfigurableWindMPH
        )
        preferences.maximumGustMPH = min(
            max(preferences.maximumGustMPH, .minimumConfigurableGustMPH),
            .maximumConfigurableGustMPH
        )
        return preferences
    }
}

extension ComfortPreferences {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idealMinimumFahrenheit = try container.decodeIfPresent(Double.self, forKey: .idealMinimumFahrenheit) ?? .defaultIdealMinimumFahrenheit
        idealMaximumFahrenheit = try container.decodeIfPresent(Double.self, forKey: .idealMaximumFahrenheit) ?? .defaultIdealMaximumFahrenheit
        maximumDewPointFahrenheit = try container.decodeIfPresent(Double.self, forKey: .maximumDewPointFahrenheit) ?? .defaultMaximumDewPointFahrenheit
        maximumRainChance = try container.decodeIfPresent(Double.self, forKey: .maximumRainChance) ?? .defaultMaximumRainChance
        maximumWindMPH = try container.decodeIfPresent(Double.self, forKey: .maximumWindMPH) ?? .defaultMaximumWindMPH
        maximumGustMPH = try container.decodeIfPresent(Double.self, forKey: .maximumGustMPH) ?? .defaultMaximumGustMPH
        alertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .alertsEnabled) ?? true
        temperatureUnit = try container.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit) ?? .fahrenheit
        temperatureEvaluationSource = try container.decodeIfPresent(TemperatureEvaluationSource.self, forKey: .temperatureEvaluationSource) ?? .feelsLike
    }
}
