import Foundation
import Testing
@testable import OpenAir
@Suite
struct ForecastTimelineSupportTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func testStatusSegmentsMergeConsecutiveMatchingStatuses() throws {
        let items = [
            try item(hour: 10, status: .open),
            try item(hour: 11, status: .open),
            try item(hour: 12, status: .keepClosed),
            try item(hour: 13, status: .keepClosed),
            try item(hour: 14, status: .open)
        ]

        let segments = ForecastStatusSegment.segments(for: items)
        let ten = try date(hour: 10)
        let twelve = try date(hour: 12)
        let fourteen = try date(hour: 14)
        let fifteen = try date(hour: 15)

        #expect(segments.count == 3)
        #expect(segments[0].start == ten)
        #expect(segments[0].end == twelve)
        #expect(segments[0].status == .open)
        #expect(segments[1].start == twelve)
        #expect(segments[1].end == fourteen)
        #expect(segments[1].status == .keepClosed)
        #expect(segments[2].start == fourteen)
        #expect(segments[2].end == fifteen)
        #expect(segments[2].status == .open)
    }

    @Test
    func testStatusSegmentsUseOneSegmentWhenAllStatusesMatch() throws {
        let items = [
            try item(hour: 10, status: .open),
            try item(hour: 11, status: .open),
            try item(hour: 12, status: .open)
        ]

        let segments = ForecastStatusSegment.segments(for: items)
        let ten = try date(hour: 10)
        let thirteen = try date(hour: 13)

        #expect(segments.count == 1)
        #expect(segments[0].start == ten)
        #expect(segments[0].end == thirteen)
        #expect(segments[0].status == .open)
    }

    @Test
    func testStatusSegmentsSmoothOneHourValidReason() throws {
        let items = [
            try item(hour: 10, status: .open),
            try item(hour: 11, status: .keepClosed, reasons: [.humid]),
            try item(hour: 12, status: .open)
        ]

        let segments = ForecastStatusSegment.segments(for: items)
        let ten = try date(hour: 10)
        let thirteen = try date(hour: 13)

        #expect(segments.count == 1)
        #expect(segments[0].start == ten)
        #expect(segments[0].end == thirteen)
        #expect(segments[0].status == .open)
    }

    @Test
    func testStatusSegmentsKeepOneHourChange() throws {
        let items = [
            try item(hour: 10, status: .open),
            try item(hour: 11, status: .keepClosed, reasons: [.thunderstorm]),
            try item(hour: 12, status: .open)
        ]

        let segments = ForecastStatusSegment.segments(for: items)
        let eleven = try date(hour: 11)
        let twelve = try date(hour: 12)

        #expect(segments.count == 3)
        #expect(segments[1].start == eleven)
        #expect(segments[1].end == twelve)
        #expect(segments[1].status == .keepClosed)
    }

    @Test
    func testDayAxisLabelsDropTooNarrowLeadingDay() throws {
        let start = try date(hour: 23, minute: 50)
        let end = try #require(calendar.date(byAdding: .hour, value: 48, to: start))

        let labels = ForecastDayAxisLabel.labels(
            for: start...end,
            width: 620,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        #expect(labels.map(\.text) == ["Tue", "Wed"])
    }

    @Test
    func testDayAxisLabelsUseWeekdaysWhenSpansFit() throws {
        let start = try date(hour: 20)
        let end = try #require(calendar.date(byAdding: .hour, value: 48, to: start))

        let labels = ForecastDayAxisLabel.labels(
            for: start...end,
            width: 620,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        #expect(labels.map(\.text) == ["Mon", "Tue", "Wed"])
    }

    @Test
    func testDayAxisLabelsDropLaterLabelsWhenSpacingIsTooTight() throws {
        let start = try date(hour: 20)
        let end = try #require(calendar.date(byAdding: .hour, value: 48, to: start))

        let labels = ForecastDayAxisLabel.labels(
            for: start...end,
            width: 110,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        #expect(labels.map(\.text) == ["Tue"])
    }

    @Test
    func testDayBoundariesReturnMidnightPositions() throws {
        let start = try date(hour: 20)
        let end = try #require(calendar.date(byAdding: .hour, value: 48, to: start))

        let boundaries = ForecastDayBoundary.boundaries(
            for: start...end,
            width: 480,
            calendar: calendar
        )
        let firstBoundaryDate = try date(hour: 24)
        let secondBoundaryDate = try date(hour: 48)

        #expect(boundaries.count == 2)
        #expect(boundaries[0].date == firstBoundaryDate)
        #expect(boundaries[0].position == 40)
        #expect(boundaries[1].date == secondBoundaryDate)
        #expect(boundaries[1].position == 280)
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
        let startOfDay = try #require(calendar.date(from: startOfDayComponents))
        let date = try #require(calendar.date(byAdding: .hour, value: hour, to: startOfDay))
        return try #require(calendar.date(byAdding: .minute, value: minute, to: date))
    }
}
