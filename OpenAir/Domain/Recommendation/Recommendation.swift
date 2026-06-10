import Foundation

enum RecommendationStatus: String, Codable, CaseIterable, Sendable {
    case open
    case keepClosed

    var title: String {
        switch self {
        case .open: "Open Now"
        case .keepClosed: "Keep Closed"
        }
    }

    var shortTitle: String {
        switch self {
        case .open: "Open"
        case .keepClosed: "Closed"
        }
    }
}

enum RecommendationReason: String, Codable, Hashable, Sendable {
    case comfortableTemperature
    case lowDewPoint
    case noRain
    case lightWind
    case temperatureOutsideRange
    case humid
    case rainRisk
    case windy
    case activePrecipitation
    case thunderstorm
    case extremeTemperature
    case extremeHumidity
    case dangerousGusts

    var label: String {
        switch self {
        case .comfortableTemperature: "Comfortable air"
        case .lowDewPoint: "Lower moisture"
        case .noRain: "No rain soon"
        case .lightWind: "Light wind"
        case .temperatureOutsideRange: "Temperature is outside your preferred range"
        case .humid: "Air is humid"
        case .rainRisk: "Rain is possible"
        case .windy: "Wind is elevated"
        case .activePrecipitation: "Precipitation is active"
        case .thunderstorm: "Thunderstorms nearby"
        case .extremeTemperature: "Temperature is unsafe"
        case .extremeHumidity: "Dew point is too high"
        case .dangerousGusts: "Wind gusts are too strong"
        }
    }

    var symbol: String {
        switch self {
        case .comfortableTemperature, .temperatureOutsideRange, .extremeTemperature: "thermometer.medium"
        case .lowDewPoint, .humid, .extremeHumidity: "drop"
        case .noRain, .rainRisk, .activePrecipitation: "cloud.rain"
        case .lightWind, .windy, .dangerousGusts: "wind"
        case .thunderstorm: "cloud.bolt.rain"
        }
    }

    var allowsTransientSmoothing: Bool {
        switch self {
        case .activePrecipitation, .thunderstorm, .extremeTemperature, .extremeHumidity, .dangerousGusts:
            false
        case .comfortableTemperature, .lowDewPoint, .noRain, .lightWind, .temperatureOutsideRange, .humid, .rainRisk, .windy:
            true
        }
    }
}

struct Recommendation: Codable, Sendable, Equatable {
    let status: RecommendationStatus
    let reasons: [RecommendationReason]
}

struct RecommendationWindow: Codable, Identifiable, Sendable, Equatable {
    let start: Date
    let end: Date
    let status: RecommendationStatus
    let reasons: [RecommendationReason]

    var id: Date { start }

    private enum CodingKeys: String, CodingKey {
        case start
        case end
        case status
        case reasons
    }

    init(
        start: Date,
        end: Date,
        status: RecommendationStatus,
        reasons: [RecommendationReason] = []
    ) {
        self.start = start
        self.end = end
        self.status = status
        self.reasons = reasons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        status = try container.decode(RecommendationStatus.self, forKey: .status)
        reasons = try container.decodeIfPresent([RecommendationReason].self, forKey: .reasons) ?? []
    }
}

struct RecommendationPlan: Sendable, Equatable {
    let current: Recommendation
    let hourly: [(weather: HourlyWeather, recommendation: Recommendation)]
    let windows: [RecommendationWindow]
    let nextChange: Date?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.current == rhs.current &&
        lhs.windows == rhs.windows &&
        lhs.nextChange == rhs.nextChange &&
        lhs.hourly.map(\.weather) == rhs.hourly.map(\.weather) &&
        lhs.hourly.map(\.recommendation) == rhs.hourly.map(\.recommendation)
    }
}

extension Array where Element == RecommendationReason {
    func merging(_ other: [RecommendationReason]) -> [RecommendationReason] {
        self + other.filter { !contains($0) }
    }
}
