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

        XCTAssertEqual(timeline.start, try date(hour: 0))
        XCTAssertEqual(timeline.end, try date(hour: 24))
        XCTAssertEqual(timeline.windows, [
            RecommendationWindow(start: try date(hour: 0), end: try date(hour: 12), status: .open),
            RecommendationWindow(start: try date(hour: 12), end: try date(hour: 24), status: .keepClosed)
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

    func testCurrentWindowLabelUsesNow() throws {
        let window = window(startHour: 8, endHour: 12, status: .open)
        let timeline = DailyWindowTimeline(
            windows: [window],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(timeline.label(for: window, calendar: calendar), "Open now → 12 PM")
    }

    func testFutureWindowLabelIsPlainStatusAndRange() throws {
        let window = window(startHour: 18, endHour: 24, status: .keepClosed)
        let timeline = DailyWindowTimeline(
            windows: [window],
            now: try date(hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(timeline.label(for: window, calendar: calendar), "Keep closed 6 PM → 12 AM")
    }

    private func window(
        startHour: Int,
        endHour: Int,
        status: RecommendationStatus
    ) -> RecommendationWindow {
        RecommendationWindow(
            start: try! date(hour: startHour),
            end: try! date(hour: endHour),
            status: status
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
}
