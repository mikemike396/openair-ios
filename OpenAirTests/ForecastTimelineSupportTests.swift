import XCTest
@testable import OpenAir

@MainActor
final class ForecastTimelineSupportTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testStatusSegmentsMergeConsecutiveMatchingStatuses() throws {
        let items = [
            try item(hour: 10, status: .open),
            try item(hour: 11, status: .open),
            try item(hour: 12, status: .keepClosed),
            try item(hour: 13, status: .keepClosed),
            try item(hour: 14, status: .open)
        ]

        let segments = ForecastStatusSegment.segments(for: items)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].start, try date(hour: 10))
        XCTAssertEqual(segments[0].end, try date(hour: 12))
        XCTAssertEqual(segments[0].status, .open)
        XCTAssertEqual(segments[1].start, try date(hour: 12))
        XCTAssertEqual(segments[1].end, try date(hour: 14))
        XCTAssertEqual(segments[1].status, .keepClosed)
        XCTAssertEqual(segments[2].start, try date(hour: 14))
        XCTAssertEqual(segments[2].end, try date(hour: 15))
        XCTAssertEqual(segments[2].status, .open)
    }

    func testStatusSegmentsUseOneSegmentWhenAllStatusesMatch() throws {
        let items = [
            try item(hour: 10, status: .open),
            try item(hour: 11, status: .open),
            try item(hour: 12, status: .open)
        ]

        let segments = ForecastStatusSegment.segments(for: items)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].start, try date(hour: 10))
        XCTAssertEqual(segments[0].end, try date(hour: 13))
        XCTAssertEqual(segments[0].status, .open)
    }

    func testStatusSegmentsSmoothOneHourValidReason() throws {
        let items = [
            try item(hour: 10, status: .open),
            try item(hour: 11, status: .keepClosed, reasons: [.humid]),
            try item(hour: 12, status: .open)
        ]

        let segments = ForecastStatusSegment.segments(for: items)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].start, try date(hour: 10))
        XCTAssertEqual(segments[0].end, try date(hour: 13))
        XCTAssertEqual(segments[0].status, .open)
    }

    func testStatusSegmentsKeepOneHourChange() throws {
        let items = [
            try item(hour: 10, status: .open),
            try item(hour: 11, status: .keepClosed, reasons: [.thunderstorm]),
            try item(hour: 12, status: .open)
        ]

        let segments = ForecastStatusSegment.segments(for: items)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[1].start, try date(hour: 11))
        XCTAssertEqual(segments[1].end, try date(hour: 12))
        XCTAssertEqual(segments[1].status, .keepClosed)
    }

    func testDayAxisLabelsDropTooNarrowLeadingDay() throws {
        let start = try date(hour: 23, minute: 50)
        let end = try XCTUnwrap(calendar.date(byAdding: .hour, value: 48, to: start))

        let labels = ForecastDayAxisLabel.labels(
            for: start...end,
            width: 620,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(labels.map(\.text), ["Tue", "Wed"])
    }

    func testDayAxisLabelsUseWeekdaysWhenSpansFit() throws {
        let start = try date(hour: 20)
        let end = try XCTUnwrap(calendar.date(byAdding: .hour, value: 48, to: start))

        let labels = ForecastDayAxisLabel.labels(
            for: start...end,
            width: 620,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(labels.map(\.text), ["Mon", "Tue", "Wed"])
    }

    func testDayAxisLabelsDropLaterLabelsWhenSpacingIsTooTight() throws {
        let start = try date(hour: 20)
        let end = try XCTUnwrap(calendar.date(byAdding: .hour, value: 48, to: start))

        let labels = ForecastDayAxisLabel.labels(
            for: start...end,
            width: 110,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(labels.map(\.text), ["Tue"])
    }

    func testDayBoundariesReturnMidnightPositions() throws {
        let start = try date(hour: 20)
        let end = try XCTUnwrap(calendar.date(byAdding: .hour, value: 48, to: start))

        let boundaries = ForecastDayBoundary.boundaries(
            for: start...end,
            width: 480,
            calendar: calendar
        )

        XCTAssertEqual(boundaries.count, 2)
        XCTAssertEqual(boundaries[0].date, try date(hour: 24))
        XCTAssertEqual(boundaries[0].position, 40)
        XCTAssertEqual(boundaries[1].date, try date(hour: 48))
        XCTAssertEqual(boundaries[1].position, 280)
    }

    private func item(
        hour: Int,
        minute: Int = 0,
        status: RecommendationStatus,
        reasons: [RecommendationReason] = []
    ) throws -> ForecastTimelineItem {
        ForecastTimelineItem(
            weather: HourlyWeather(
                date: try date(hour: hour, minute: minute),
                temperatureFahrenheit: 70,
                dewPointFahrenheit: 50,
                precipitationChance: 0,
                isPrecipitating: false,
                isThunderstorm: false,
                windMPH: 0,
                gustMPH: nil,
                symbolName: "sun.max"
            ),
            status: status,
            reasons: reasons,
            unit: .fahrenheit
        )
    }

    private func date(hour: Int, minute: Int = 0) throws -> Date {
        let startOfDayComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 8
        )
        let startOfDay = try XCTUnwrap(calendar.date(from: startOfDayComponents))
        let date = try XCTUnwrap(calendar.date(byAdding: .hour, value: hour, to: startOfDay))
        return try XCTUnwrap(calendar.date(byAdding: .minute, value: minute, to: date))
    }
}
