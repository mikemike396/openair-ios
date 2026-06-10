import Foundation
import Testing
@testable import OpenAir

struct RecommendationChangeTextTests {
    @Test
    @MainActor
    func includesTimeAndWeekday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 12,
            hour: 14
        )))

        let text = RecommendationChangeText.text(
            for: date,
            locale: Locale(identifier: "en_US"),
            calendar: calendar
        )

        #expect(text.hasPrefix("Expected to change around "))
        #expect(text.contains("2:00"))
        #expect(text.hasSuffix("Friday"))
    }
}
