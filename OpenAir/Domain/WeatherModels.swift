import CoreLocation
import Foundation

struct WeatherSnapshot: Codable, Sendable, Equatable {
    let locationName: String
    let coordinate: Coordinate
    let fetchedAt: Date
    let current: HourlyWeather
    let hourly: [HourlyWeather]

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 60 * 60 * 3
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
    let dewPointFahrenheit: Double
    let precipitationChance: Double
    let isPrecipitating: Bool
    let isThunderstorm: Bool
    let windMPH: Double
    let gustMPH: Double?
    let symbolName: String

    var id: Date { date }
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
