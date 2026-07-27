import Foundation

struct ForecastTimelineItem: Identifiable {
    let weather: HourlyWeather
    let status: RecommendationStatus
    let reasons: [RecommendationReason]
    let unit: TemperatureUnit
    let temperatureSource: TemperatureEvaluationSource

    var id: Date { weather.date }
    var date: Date { weather.date }
    var temperature: Double { unit.chartValue(weather.temperatureFahrenheit(for: temperatureSource)) }
    var dewPoint: Double { unit.chartValue(weather.dewPointFahrenheit) }
}

extension Array where Element == ForecastTimelineItem {
    func nearest(to date: Date) -> ForecastTimelineItem? {
        self.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
}

extension TemperatureUnit {
    func chartValue(_ fahrenheit: Double) -> Double {
        switch self {
        case .fahrenheit: fahrenheit
        case .celsius: (fahrenheit - 32) * 5 / 9
        }
    }
}
