import CoreLocation
import Foundation
import WeatherKit

protocol WeatherProviding: Sendable {
    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot
}

struct WeatherKitClient: WeatherProviding {
    private let service = WeatherService.shared

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 48, to: startDate) ?? startDate.addingTimeInterval(48 * 60 * 60)
        let weather = try await service.weather(
            for: coordinate.clLocation,
            including: .current, .hourly(startDate: startDate, endDate: endDate)
        )
        let current = map(
            date: weather.0.date,
            temperature: weather.0.temperature,
            dewPoint: weather.0.dewPoint,
            precipitationChance: 0,
            condition: weather.0.condition,
            wind: weather.0.wind,
            symbolName: weather.0.symbolName
        )
        let hourly = weather.1.forecast.prefix(48).map {
            map(
                date: $0.date,
                temperature: $0.temperature,
                dewPoint: $0.dewPoint,
                precipitationChance: $0.precipitationChance,
                condition: $0.condition,
                wind: $0.wind,
                symbolName: $0.symbolName
            )
        }
        return WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: .now,
            current: current,
            hourly: Array(hourly)
        )
    }

    private func map(
        date: Date,
        temperature: Measurement<UnitTemperature>,
        dewPoint: Measurement<UnitTemperature>,
        precipitationChance: Double,
        condition: WeatherCondition,
        wind: Wind,
        symbolName: String
    ) -> HourlyWeather {
        let conditionText = String(describing: condition).lowercased()
        let thunder = conditionText.contains("thunder") || conditionText.contains("storm")
        let precipitating = ["rain", "drizzle", "snow", "sleet", "flurr", "wintry"].contains {
            conditionText.contains($0)
        }
        return HourlyWeather(
            date: date,
            temperatureFahrenheit: temperature.converted(to: .fahrenheit).value,
            dewPointFahrenheit: dewPoint.converted(to: .fahrenheit).value,
            precipitationChance: precipitationChance,
            isPrecipitating: precipitating,
            isThunderstorm: thunder,
            windMPH: wind.speed.converted(to: .milesPerHour).value,
            gustMPH: wind.gust?.converted(to: .milesPerHour).value,
            symbolName: symbolName
        )
    }
}

struct PreviewWeatherClient: WeatherProviding {
    var snapshot = WeatherSnapshot.preview
    var error: (any Error)?

    func fetchWeather(for coordinate: Coordinate, locationName: String) async throws -> WeatherSnapshot {
        if let error { throw error }
        return WeatherSnapshot(
            locationName: locationName,
            coordinate: coordinate,
            fetchedAt: snapshot.fetchedAt,
            current: snapshot.current,
            hourly: snapshot.hourly
        )
    }
}

extension WeatherSnapshot {
    static var preview: WeatherSnapshot {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .hour, for: .now)?.start ?? .now
        let values: [(Double, Double, Double, Double, String)] = [
            (64, 52, 0.05, 5, "sun.max.fill"),
            (66, 54, 0.05, 6, "sun.max.fill"),
            (69, 57, 0.10, 7, "sun.max.fill"),
            (74, 62, 0.25, 9, "cloud.sun.fill"),
            (78, 65, 0.35, 12, "cloud.fill"),
            (82, 69, 0.45, 16, "cloud.rain.fill"),
            (76, 64, 0.15, 10, "cloud.sun.fill"),
            (71, 58, 0.05, 7, "moon.stars.fill"),
            (67, 55, 0.05, 4, "moon.stars.fill")
        ]
        let hourly = values.enumerated().map { index, value in
            HourlyWeather(
                date: calendar.date(byAdding: .hour, value: index, to: start) ?? start,
                temperatureFahrenheit: value.0,
                dewPointFahrenheit: value.1,
                precipitationChance: value.2,
                isPrecipitating: false,
                isThunderstorm: false,
                windMPH: value.3,
                gustMPH: value.3 + 4,
                symbolName: value.4
            )
        }
        return WeatherSnapshot(
            locationName: "Wilmington, DE",
            coordinate: .init(latitude: 39.7391, longitude: -75.5398),
            fetchedAt: .now,
            current: hourly[0],
            hourly: hourly
        )
    }
}
