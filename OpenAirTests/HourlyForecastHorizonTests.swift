import Foundation
import Testing
@testable import OpenAir

@Suite
struct HourlyForecastHorizonTests {
    @Test
    func endsTwoHundredFortyHoursAfterTheStart() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        let end = HourlyForecastHorizon.endDate(from: start, calendar: calendar)

        #expect(HourlyForecastHorizon.dayCount == 10)
        #expect(HourlyForecastHorizon.hourCount == 240)
        #expect(end.timeIntervalSince(start) == 240 * 60 * 60)
    }
}
