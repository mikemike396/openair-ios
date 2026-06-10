import XCTest
@testable import OpenAir

@MainActor
final class DayStatusBarAxisTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testUsesFourHourMarkersWhenMoreThanEightHoursRemain() throws {
        let markers = DayStatusBarAxis.markerDates(
            start: try date(hour: 10),
            end: try date(hour: 24),
            calendar: calendar
        )

        XCTAssertEqual(markers, [
            try date(hour: 12),
            try date(hour: 16),
            try date(hour: 20)
        ])
    }

    func testUsesTwoHourMarkersWhenThreeToEightHoursRemain() throws {
        let markers = DayStatusBarAxis.markerDates(
            start: try date(hour: 16),
            end: try date(hour: 24),
            calendar: calendar
        )

        XCTAssertEqual(markers, [
            try date(hour: 18),
            try date(hour: 20),
            try date(hour: 22)
        ])
    }

    func testUsesHourlyMarkersWhenUnderThreeHoursRemain() throws {
        let markers = DayStatusBarAxis.markerDates(
            start: try date(hour: 21, minute: 30),
            end: try date(hour: 24),
            calendar: calendar
        )

        XCTAssertEqual(markers, [
            try date(hour: 22),
            try date(hour: 23)
        ])
    }

    func testOmitsMarkersOutsideRange() throws {
        let markers = DayStatusBarAxis.markerDates(
            start: try date(hour: 22),
            end: try date(hour: 24),
            calendar: calendar
        )

        XCTAssertEqual(markers, [try date(hour: 23)])
    }

    private func date(hour: Int, minute: Int = 0) throws -> Date {
        let startOfDayComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 7
        )
        let startOfDay = try XCTUnwrap(calendar.date(from: startOfDayComponents))
        let date = try XCTUnwrap(calendar.date(byAdding: .hour, value: hour, to: startOfDay))
        return try XCTUnwrap(calendar.date(byAdding: .minute, value: minute, to: date))
    }
}
