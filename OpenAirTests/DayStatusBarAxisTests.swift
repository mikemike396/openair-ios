import Foundation
import Testing
@testable import OpenAir
@Suite
struct DayStatusBarAxisTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func testUsesFourHourMarkersWhenMoreThanEightHoursRemain() throws {
        let markers = DayStatusBarAxis.markerDates(
            start: try date(hour: 10),
            end: try date(hour: 24),
            calendar: calendar
        )

        let expectedMarkers = [
            try date(hour: 12),
            try date(hour: 16),
            try date(hour: 20)
        ]
        #expect(markers == expectedMarkers)
    }

    @Test
    func testUsesTwoHourMarkersWhenThreeToEightHoursRemain() throws {
        let markers = DayStatusBarAxis.markerDates(
            start: try date(hour: 16),
            end: try date(hour: 24),
            calendar: calendar
        )

        let expectedMarkers = [
            try date(hour: 18),
            try date(hour: 20),
            try date(hour: 22)
        ]
        #expect(markers == expectedMarkers)
    }

    @Test
    func testUsesHourlyMarkersWhenUnderThreeHoursRemain() throws {
        let markers = DayStatusBarAxis.markerDates(
            start: try date(hour: 21, minute: 30),
            end: try date(hour: 24),
            calendar: calendar
        )

        let expectedMarkers = [
            try date(hour: 22),
            try date(hour: 23)
        ]
        #expect(markers == expectedMarkers)
    }

    @Test
    func testOmitsMarkersOutsideRange() throws {
        let markers = DayStatusBarAxis.markerDates(
            start: try date(hour: 22),
            end: try date(hour: 24),
            calendar: calendar
        )

        let expectedMarkers = [try date(hour: 23)]
        #expect(markers == expectedMarkers)
    }

    private func date(hour: Int, minute: Int = 0) throws -> Date {
        let startOfDayComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 7
        )
        let startOfDay = try #require(calendar.date(from: startOfDayComponents))
        let date = try #require(calendar.date(byAdding: .hour, value: hour, to: startOfDay))
        return try #require(calendar.date(byAdding: .minute, value: minute, to: date))
    }
}
