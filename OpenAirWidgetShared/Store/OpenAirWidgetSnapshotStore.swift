import Foundation

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

    @discardableResult
    func save(_ snapshot: OpenAirWidgetSnapshot) -> Bool {
        if let storedSnapshot = load(), snapshot.publishedAt <= storedSnapshot.publishedAt {
            return false
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }
        userDefaults.set(data, forKey: Self.snapshotKey)
        return true
    }

    @discardableResult
    func save(data: Data) -> Bool {
        guard let snapshot = try? JSONDecoder().decode(OpenAirWidgetSnapshot.self, from: data) else {
            return false
        }
        return save(snapshot)
    }

    static func encoded(_ snapshot: OpenAirWidgetSnapshot) -> Data? {
        try? JSONEncoder().encode(snapshot)
    }
}
