import Foundation

struct WeatherCache: Sendable {
    private let url: URL

    init(fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        url = directory.appending(path: "weather-snapshot.json")
    }

    init(url: URL) {
        self.url = url
    }

    func load() -> WeatherSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
    }

    func save(_ snapshot: WeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
