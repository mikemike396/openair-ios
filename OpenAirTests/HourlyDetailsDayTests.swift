import Foundation
import Testing
@testable import OpenAir

@Suite
struct HourlyDetailsDayTests {
    @Test
    func groupsHoursByLocalDayInChronologicalOrder() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 23)))
        let items = [
            item(date: start.addingTimeInterval(2 * 60 * 60)),
            item(date: start),
            item(date: start.addingTimeInterval(60 * 60))
        ]

        let groups = HourlyDetailsDay.groups(for: items, calendar: calendar)

        #expect(groups.count == 2)
        #expect(groups[0].items.map(\.weather.date) == [start])
        #expect(groups[1].items.map(\.weather.date) == [
            start.addingTimeInterval(60 * 60),
            start.addingTimeInterval(2 * 60 * 60)
        ])
    }

    @Test
    func groupsAllHoursInTheTenDayForecast() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8)))
        let items = (0..<HourlyForecastHorizon.hourCount).map { offset in
            item(date: start.addingTimeInterval(Double(offset * 60 * 60)))
        }

        let groups = HourlyDetailsDay.groups(for: items, calendar: calendar)

        #expect(groups.count == HourlyForecastHorizon.dayCount)
        #expect(groups.allSatisfy { $0.items.count == 24 })
        #expect(groups.flatMap(\.items).count == HourlyForecastHorizon.hourCount)
    }

    private func item(date: Date) -> (weather: HourlyWeather, recommendation: Recommendation) {
        (
            weather: HourlyWeather(
                date: date,
                temperatureFahrenheit: 70,
                dewPointFahrenheit: 50,
                precipitationChance: 0,
                isPrecipitating: false,
                isThunderstorm: false,
                windMPH: 0,
                gustMPH: nil,
                symbolName: "sun.max"
            ),
            recommendation: Recommendation(status: .open, reasons: [])
        )
    }
}
