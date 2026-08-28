import Foundation

enum ForecastRange: String, CaseIterable, Codable, Identifiable, Sendable {
    case oneDay
    case twoDays
    case fiveDays
    case sevenDays
    case tenDays

    var id: Self { self }

    var hourCount: Int {
        switch self {
        case .oneDay: 24
        case .twoDays: 48
        case .fiveDays: 120
        case .sevenDays: 168
        case .tenDays: HourlyForecastHorizon.hourCount
        }
    }

    var title: String {
        switch self {
        case .oneDay: "24 hours"
        case .twoDays: "2 days"
        case .fiveDays: "5 days"
        case .sevenDays: "7 days"
        case .tenDays: "10 days"
        }
    }
}
