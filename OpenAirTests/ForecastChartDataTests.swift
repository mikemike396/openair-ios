import Foundation
import Testing
@testable import OpenAir

@Suite
@MainActor
struct ForecastChartDataTests {
    @Test
    func buildsAtMostFortyEightConvertedTimelineItems() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceItems = (0..<50).map { offset in
            forecastItem(
                date: start.addingTimeInterval(Double(offset) * 60 * 60),
                temperature: 68,
                dewPoint: 50
            )
        }

        let data = ForecastChartData(
            items: sourceItems,
            unit: .celsius,
            preferences: ComfortPreferences()
        )

        #expect(data.items.count == 48)
        #expect(data.items[0].temperature == 20)
        #expect(data.items[0].dewPoint == 10)
        #expect(data.xDomain.lowerBound == start)
        #expect(data.xDomain.upperBound == start.addingTimeInterval(48 * 60 * 60))
    }

    @Test
    func precomputesDomainsAndStatusSegments() {
        var preferences = ComfortPreferences()
        preferences.idealMinimumFahrenheit = 55
        preferences.idealMaximumFahrenheit = 75
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceItems = [
            forecastItem(date: start, temperature: 60, dewPoint: 45, status: .open),
            forecastItem(
                date: start.addingTimeInterval(60 * 60),
                temperature: 80,
                dewPoint: 65,
                status: .keepClosed
            )
        ]

        let data = ForecastChartData(
            items: sourceItems,
            unit: .fahrenheit,
            preferences: preferences
        )

        #expect(data.temperature.referenceLines.map(\.value) == [55, 75])
        #expect(data.temperature.yDomain.lowerBound < 55)
        #expect(data.temperature.yDomain.upperBound > 80)
        #expect(data.statusSegments.count == 2)
    }

    @Test
    func findsNearestItemForSelectionDate() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceItems = [
            forecastItem(date: start, temperature: 60, dewPoint: 45),
            forecastItem(
                date: start.addingTimeInterval(60 * 60),
                temperature: 62,
                dewPoint: 47
            )
        ]
        let data = ForecastChartData(
            items: sourceItems,
            unit: .fahrenheit,
            preferences: ComfortPreferences()
        )

        let selected = try #require(
            data.nearestItem(to: start.addingTimeInterval(50 * 60))
        )

        #expect(selected.date == start.addingTimeInterval(60 * 60))
    }

    private func forecastItem(
        date: Date,
        temperature: Double,
        dewPoint: Double,
        status: RecommendationStatus = .open
    ) -> (weather: HourlyWeather, recommendation: Recommendation) {
        (
            weather: HourlyWeather(
                date: date,
                temperatureFahrenheit: temperature,
                dewPointFahrenheit: dewPoint,
                precipitationChance: 0,
                isPrecipitating: false,
                isThunderstorm: false,
                windMPH: 0,
                gustMPH: nil,
                symbolName: "sun.max"
            ),
            recommendation: Recommendation(status: status, reasons: [])
        )
    }
}
