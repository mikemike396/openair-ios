import Testing
@testable import OpenAir

@Suite
struct ForecastRangeTests {
    @Test(arguments: [
        (ForecastRange.oneDay, 24),
        (.twoDays, 48),
        (.fiveDays, 120),
        (.sevenDays, 168),
        (.tenDays, 240)
    ])
    func mapsEachRangeToTheExpectedHourlyLimit(
        range: ForecastRange,
        expectedHourCount: Int
    ) {
        #expect(range.hourCount == expectedHourCount)
    }
}
