import XCTest
@testable import OpenAir

final class DailyWindowTimelineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testClipsVisibleWindowsToCurrentDay() throws {
        let now = try date(hour: 10)
        let timeline = DailyWindowTimeline(
            windows: [
                window(startHour: 8, endHour: 12, status: .open),
                window(startHour: 12, endHour: 28, status: .keepClosed)
            ],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(timeline.start, now)
        XCTAssertEqual(timeline.end, try date(hour: 24))
        XCTAssertEqual(timeline.windows, [
            RecommendationWindow(start: try date(hour: 10), end: try date(hour: 12), status: .open),
            RecommendationWindow(start: try date(hour: 12), end: try date(hour: 24), status: .keepClosed)
        ])
    }

    func testCurrentWindowIsClippedToNow() throws {
        let now = try date(hour: 10)
        let timeline = DailyWindowTimeline(
            windows: [window(startHour: 8, endHour: 12, status: .open)],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(timeline.windows, [
            RecommendationWindow(start: now, end: try date(hour: 12), status: .open)
        ])
    }

    func testDropsExpiredAndTomorrowOnlyWindows() throws {
        let timeline = DailyWindowTimeline(
            windows: [
                window(startHour: 6, endHour: 9, status: .open),
                window(startHour: 26, endHour: 28, status: .keepClosed)
            ],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(timeline.windows, [])
    }

    func testSmoothsOneHourValidReasonForDisplay() throws {
        let timeline = DailyWindowTimeline(
            windows: [
                window(startHour: 10, endHour: 12, status: .open),
                window(startHour: 12, endHour: 13, status: .keepClosed, reasons: [.humid]),
                window(startHour: 13, endHour: 16, status: .open)
            ],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(timeline.windows, [
            RecommendationWindow(start: try date(hour: 10), end: try date(hour: 16), status: .open)
        ])
    }

    func testKeepsOneHourChangeForDisplay() throws {
        let timeline = DailyWindowTimeline(
            windows: [
                window(startHour: 10, endHour: 12, status: .open),
                window(startHour: 12, endHour: 13, status: .keepClosed, reasons: [.activePrecipitation]),
                window(startHour: 13, endHour: 16, status: .open)
            ],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(timeline.windows.count, 3)
        XCTAssertEqual(timeline.windows[1].status, .keepClosed)
        XCTAssertEqual(timeline.windows[1].reasons, [.activePrecipitation])
    }

    func testCurrentWindowLabelUsesNow() throws {
        let window = window(startHour: 8, endHour: 12, status: .open)
        let timeline = DailyWindowTimeline(
            windows: [window],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(
            normalizedTimeSpacing(timeline.label(for: window, calendar: calendar, locale: Locale(identifier: "en_US"))),
            "Open now → 12 PM"
        )
    }

    func testFutureWindowLabelIsPlainStatusAndRange() throws {
        let window = window(startHour: 18, endHour: 24, status: .keepClosed)
        let timeline = DailyWindowTimeline(
            windows: [window],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(
            normalizedTimeSpacing(timeline.label(for: window, calendar: calendar, locale: Locale(identifier: "en_US"))),
            "Keep closed 6 PM → 12 AM"
        )
    }

    func testLabelsSupportTwentyFourHourLocale() throws {
        let window = window(startHour: 18, endHour: 24, status: .keepClosed)
        let timeline = DailyWindowTimeline(
            windows: [window],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(
            timeline.label(for: window, calendar: calendar, locale: Locale(identifier: "en_GB")),
            "Keep closed 18 → 00"
        )
    }

    func testCurrentWindowLabelSupportsTwentyFourHourLocale() throws {
        let window = window(startHour: 8, endHour: 12, status: .open)
        let timeline = DailyWindowTimeline(
            windows: [window],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(
            timeline.label(for: window, calendar: calendar, locale: Locale(identifier: "en_GB")),
            "Open now → 12"
        )
    }

    private func window(
        startHour: Int,
        endHour: Int,
        status: RecommendationStatus,
        reasons: [RecommendationReason] = []
    ) -> RecommendationWindow {
        RecommendationWindow(
            start: try! date(hour: startHour),
            end: try! date(hour: endHour),
            status: status,
            reasons: reasons
        )
    }

    private func date(hour: Int) throws -> Date {
        let startOfDayComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 7
        )
        let startOfDay = try XCTUnwrap(calendar.date(from: startOfDayComponents))
        return try XCTUnwrap(calendar.date(byAdding: .hour, value: hour, to: startOfDay))
    }

    private func normalizedTimeSpacing(_ label: String) -> String {
        label.replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
