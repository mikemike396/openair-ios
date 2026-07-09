import Foundation

enum OpenAirWidgetRecommendationStatus: String, Codable, Sendable, Equatable {
    case open
    case keepClosed

    var symbolName: String {
        switch self {
        case .open: "window.vertical.open"
        case .keepClosed: "window.vertical.closed"
        }
    }
}

struct OpenAirWidgetSnapshot: Codable, Sendable, Equatable {
    let status: OpenAirWidgetRecommendationStatus
    let temperature: Int
    let dewPoint: Int
    let windMPH: Int
    let conditionSymbolName: String
    let unitSymbol: String
    let fetchedAt: Date
    let locationName: String
    let nextChange: Date?

    init(
        status: OpenAirWidgetRecommendationStatus,
        temperature: Int,
        dewPoint: Int,
        windMPH: Int,
        conditionSymbolName: String = "cloud",
        unitSymbol: String,
        fetchedAt: Date,
        locationName: String,
        nextChange: Date? = nil
    ) {
        self.status = status
        self.temperature = temperature
        self.dewPoint = dewPoint
        self.windMPH = windMPH
        self.conditionSymbolName = conditionSymbolName
        self.unitSymbol = unitSymbol
        self.fetchedAt = fetchedAt
        self.locationName = locationName
        self.nextChange = nextChange
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case temperature
        case dewPoint
        case windMPH
        case conditionSymbolName
        case unitSymbol
        case fetchedAt
        case locationName
        case nextChange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(OpenAirWidgetRecommendationStatus.self, forKey: .status)
        temperature = try container.decode(Int.self, forKey: .temperature)
        dewPoint = try container.decode(Int.self, forKey: .dewPoint)
        windMPH = try container.decodeIfPresent(Int.self, forKey: .windMPH) ?? 0
        conditionSymbolName = try container.decodeIfPresent(String.self, forKey: .conditionSymbolName) ?? "cloud"
        unitSymbol = try container.decode(String.self, forKey: .unitSymbol)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        locationName = try container.decode(String.self, forKey: .locationName)
        nextChange = try container.decodeIfPresent(Date.self, forKey: .nextChange)
    }
}
