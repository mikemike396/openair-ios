import Foundation
import Testing
@testable import OpenAir

@Test
func weatherCacheLoadsLegacySnapshotWithoutApparentTemperature() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "WeatherCacheTests.\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }

    let weather: [String: Any] = [
        "date": 1_800,
        "temperatureFahrenheit": 60,
        "dewPointFahrenheit": 50,
        "precipitationChance": 0.1,
        "isPrecipitating": false,
        "isThunderstorm": false,
        "windMPH": 12,
        "gustMPH": 18,
        "symbolName": "sun.max"
    ]
    let payload: [String: Any] = [
        "locationName": "Wilmington, DE",
        "coordinate": ["latitude": 39.7391, "longitude": -75.5398],
        "fetchedAt": 1_800,
        "current": weather,
        "hourly": [weather]
    ]
    try JSONSerialization.data(withJSONObject: payload).write(to: url)

    let snapshot = try #require(WeatherCache(url: url).load())

    #expect(snapshot.current.temperatureFahrenheit == 60)
    #expect(snapshot.current.apparentTemperatureFahrenheit == 60)
    #expect(snapshot.hourly[0].apparentTemperatureFahrenheit == 60)
}
