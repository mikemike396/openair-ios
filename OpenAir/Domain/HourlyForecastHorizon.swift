import Foundation

enum HourlyForecastHorizon {
    static let dayCount = 10
    static let hourCount = dayCount * 24

    static func endDate(from startDate: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .hour, value: hourCount, to: startDate)
            ?? startDate.addingTimeInterval(TimeInterval(hourCount * 60 * 60))
    }
}
