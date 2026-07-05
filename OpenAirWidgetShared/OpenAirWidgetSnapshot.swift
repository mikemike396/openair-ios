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
    let unitSymbol: String
    let fetchedAt: Date
    let locationName: String

    init(
        status: OpenAirWidgetRecommendationStatus,
        temperature: Int,
        dewPoint: Int,
        windMPH: Int,
        unitSymbol: String,
        fetchedAt: Date,
        locationName: String
    ) {
        self.status = status
        self.temperature = temperature
        self.dewPoint = dewPoint
        self.windMPH = windMPH
        self.unitSymbol = unitSymbol
        self.fetchedAt = fetchedAt
        self.locationName = locationName
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case temperature
        case dewPoint
        case windMPH
        case unitSymbol
        case fetchedAt
        case locationName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(OpenAirWidgetRecommendationStatus.self, forKey: .status)
        temperature = try container.decode(Int.self, forKey: .temperature)
        dewPoint = try container.decode(Int.self, forKey: .dewPoint)
        windMPH = try container.decodeIfPresent(Int.self, forKey: .windMPH) ?? 0
        unitSymbol = try container.decode(String.self, forKey: .unitSymbol)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        locationName = try container.decode(String.self, forKey: .locationName)
    }
}

struct OpenAirWidgetSnapshotStore {
    nonisolated static let suiteName = "group.com.openairapp.openair"
    nonisolated static let snapshotDidChangeNotification = Notification.Name("OpenAirWidgetSnapshotDidChange")
    nonisolated static let watchTransferSnapshotDataKey = "snapshotData"

    nonisolated private static let snapshotKey = "openAirWidgetSnapshot"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: Self.suiteName)) {
        self.userDefaults = userDefaults ?? .standard
    }

    func load() -> OpenAirWidgetSnapshot? {
        guard let data = userDefaults.data(forKey: Self.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(OpenAirWidgetSnapshot.self, from: data)
    }

    func save(_ snapshot: OpenAirWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: Self.snapshotKey)
        NotificationCenter.default.post(name: Self.snapshotDidChangeNotification, object: nil)
    }

    func save(data: Data) {
        userDefaults.set(data, forKey: Self.snapshotKey)
        NotificationCenter.default.post(name: Self.snapshotDidChangeNotification, object: nil)
    }

    static func encoded(_ snapshot: OpenAirWidgetSnapshot) -> Data? {
        try? JSONEncoder().encode(snapshot)
    }
}
