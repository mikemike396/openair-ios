import CoreLocation
import Foundation

struct WeatherSnapshot: Codable, Sendable, Equatable {
    let locationName: String
    let coordinate: Coordinate
    let fetchedAt: Date
    let current: HourlyWeather
    let hourly: [HourlyWeather]

    var isStale: Bool {
        Date.now.timeIntervalSince(fetchedAt) > .staleCacheInterval
    }
}

struct Coordinate: Codable, Sendable, Equatable {
    let latitude: Double
    let longitude: Double

    init(_ location: CLLocationCoordinate2D) {
        latitude = location.latitude
        longitude = location.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct HourlyWeather: Codable, Identifiable, Sendable, Equatable {
    let date: Date
    let temperatureFahrenheit: Double
    let apparentTemperatureFahrenheit: Double
    let dewPointFahrenheit: Double
    let precipitationChance: Double
    let isPrecipitating: Bool
    let isThunderstorm: Bool
    let windMPH: Double
    let gustMPH: Double?
    let symbolName: String

    var id: Date { date }

    func temperatureFahrenheit(for source: TemperatureEvaluationSource) -> Double {
        switch source {
        case .actual:
            temperatureFahrenheit
        case .feelsLike:
            apparentTemperatureFahrenheit
        }
    }

    init(
        date: Date,
        temperatureFahrenheit: Double,
        apparentTemperatureFahrenheit: Double? = nil,
        dewPointFahrenheit: Double,
        precipitationChance: Double,
        isPrecipitating: Bool,
        isThunderstorm: Bool,
        windMPH: Double,
        gustMPH: Double?,
        symbolName: String
    ) {
        self.date = date
        self.temperatureFahrenheit = temperatureFahrenheit
        self.apparentTemperatureFahrenheit = apparentTemperatureFahrenheit ?? temperatureFahrenheit
        self.dewPointFahrenheit = dewPointFahrenheit
        self.precipitationChance = precipitationChance
        self.isPrecipitating = isPrecipitating
        self.isThunderstorm = isThunderstorm
        self.windMPH = windMPH
        self.gustMPH = gustMPH
        self.symbolName = symbolName
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case temperatureFahrenheit
        case apparentTemperatureFahrenheit
        case dewPointFahrenheit
        case precipitationChance
        case isPrecipitating
        case isThunderstorm
        case windMPH
        case gustMPH
        case symbolName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let temperatureFahrenheit = try container.decode(Double.self, forKey: .temperatureFahrenheit)
        self.init(
            date: try container.decode(Date.self, forKey: .date),
            temperatureFahrenheit: temperatureFahrenheit,
            apparentTemperatureFahrenheit: try container.decodeIfPresent(Double.self, forKey: .apparentTemperatureFahrenheit),
            dewPointFahrenheit: try container.decode(Double.self, forKey: .dewPointFahrenheit),
            precipitationChance: try container.decode(Double.self, forKey: .precipitationChance),
            isPrecipitating: try container.decode(Bool.self, forKey: .isPrecipitating),
            isThunderstorm: try container.decode(Bool.self, forKey: .isThunderstorm),
            windMPH: try container.decode(Double.self, forKey: .windMPH),
            gustMPH: try container.decodeIfPresent(Double.self, forKey: .gustMPH),
            symbolName: try container.decode(String.self, forKey: .symbolName)
        )
    }
}

struct SavedPlace: Codable, Sendable, Equatable, Identifiable {
    let name: String
    let coordinate: Coordinate
    var id: String { "\(coordinate.latitude),\(coordinate.longitude)" }
}

enum TemperatureUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case fahrenheit
    case celsius

    var id: Self { self }
    var symbol: String { self == .fahrenheit ? "°F" : "°C" }

    func display(_ fahrenheit: Double) -> Int {
        let value = self == .fahrenheit ? fahrenheit : (fahrenheit - 32) * 5 / 9
        return Int(value.rounded())
    }
}

enum TemperatureEvaluationSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case actual
    case feelsLike

    var id: Self { self }

    var title: String {
        switch self {
        case .actual:
            "Actual temperature"
        case .feelsLike:
            "Feels like"
        }
    }

    var temperatureLabel: String {
        switch self {
        case .actual:
            "Temperature"
        case .feelsLike:
            "Feels like"
        }
    }
}
