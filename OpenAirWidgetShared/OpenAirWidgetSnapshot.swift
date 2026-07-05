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
    let unitSymbol: String
    let fetchedAt: Date
    let locationName: String
}

struct OpenAirWidgetSnapshotStore {
    nonisolated static let suiteName = "group.com.openairapp.openair"
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
    }

    func save(data: Data) {
        userDefaults.set(data, forKey: Self.snapshotKey)
    }

    static func encoded(_ snapshot: OpenAirWidgetSnapshot) -> Data? {
        try? JSONEncoder().encode(snapshot)
    }
}
