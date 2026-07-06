import Foundation
import Testing
@testable import OpenAir

@MainActor
@Test
func widgetSnapshotUsesCurrentRecommendationAndDewPoint() {
    let snapshot = WeatherSnapshot.preview
    let preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
    let basePlan = RecommendationEngine().plan(snapshot: snapshot, preferences: preferences)
    let nextChange = Date(timeIntervalSince1970: 7_200)
    let plan = RecommendationPlan(
        current: basePlan.current,
        hourly: basePlan.hourly,
        windows: basePlan.windows,
        nextChange: nextChange
    )

    let widgetSnapshot = WidgetSnapshotFactory().makeSnapshot(
        weather: snapshot,
        plan: plan,
        preferences: preferences
    )

    #expect(widgetSnapshot.status == .open)
    #expect(widgetSnapshot.status.symbolName == "window.vertical.open")
    #expect(widgetSnapshot.temperature == 64)
    #expect(widgetSnapshot.dewPoint == 52)
    #expect(widgetSnapshot.windMPH == 5)
    #expect(widgetSnapshot.conditionSymbolName == snapshot.current.symbolName)
    #expect(widgetSnapshot.unitSymbol == "°F")
    #expect(widgetSnapshot.locationName == "Wilmington, DE")
    #expect(widgetSnapshot.nextChange == nextChange)
}

@MainActor
@Test
func widgetSnapshotUsesCelsiusPreference() {
    var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
    preferences.temperatureUnit = .celsius
    let snapshot = WeatherSnapshot.preview
    let plan = RecommendationEngine().plan(snapshot: snapshot, preferences: preferences)

    let widgetSnapshot = WidgetSnapshotFactory().makeSnapshot(
        weather: snapshot,
        plan: plan,
        preferences: preferences
    )

    #expect(widgetSnapshot.temperature == 18)
    #expect(widgetSnapshot.dewPoint == 11)
    #expect(widgetSnapshot.unitSymbol == "°C")
}

@MainActor
@Test
func widgetSnapshotStoreRoundTripsPayload() throws {
    let defaults = try #require(UserDefaults(suiteName: "WidgetSnapshotTests.\(UUID().uuidString)"))
    let store = OpenAirWidgetSnapshotStore(userDefaults: defaults)
    let snapshot = OpenAirWidgetSnapshot(
        status: .keepClosed,
        temperature: 72,
        dewPoint: 68,
        windMPH: 12,
        conditionSymbolName: "cloud.sun.fill",
        unitSymbol: "°F",
        fetchedAt: Date(timeIntervalSince1970: 1_800),
        locationName: "Wilmington, DE",
        nextChange: Date(timeIntervalSince1970: 7_200)
    )

    store.save(snapshot)

    #expect(store.load() == snapshot)
    #expect(snapshot.status.symbolName == "window.vertical.closed")
}

@MainActor
@Test
func widgetSnapshotDecodesOlderPayloadWithoutNextChange() throws {
    let payload: [String: Any] = [
        "status": "open",
        "temperature": 72,
        "dewPoint": 58,
        "windMPH": 5,
        "unitSymbol": "°F",
        "fetchedAt": 1_800,
        "locationName": "Wilmington, DE"
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)

    let snapshot = try JSONDecoder().decode(OpenAirWidgetSnapshot.self, from: data)

    #expect(snapshot.status == .open)
    #expect(snapshot.temperature == 72)
    #expect(snapshot.dewPoint == 58)
    #expect(snapshot.windMPH == 5)
    #expect(snapshot.conditionSymbolName == "cloud")
    #expect(snapshot.unitSymbol == "°F")
    #expect(snapshot.fetchedAt == Date(timeIntervalSinceReferenceDate: 1_800))
    #expect(snapshot.locationName == "Wilmington, DE")
    #expect(snapshot.nextChange == nil)
}
