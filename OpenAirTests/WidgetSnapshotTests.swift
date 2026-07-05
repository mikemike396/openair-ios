import Foundation
import Testing
@testable import OpenAir

@MainActor
@Test
func widgetSnapshotUsesCurrentRecommendationAndDewPoint() {
    let snapshot = WeatherSnapshot.preview
    let preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
    let plan = RecommendationEngine().plan(snapshot: snapshot, preferences: preferences)

    let widgetSnapshot = WidgetSnapshotFactory().makeSnapshot(
        weather: snapshot,
        plan: plan,
        preferences: preferences
    )

    #expect(widgetSnapshot.status == .open)
    #expect(widgetSnapshot.status.symbolName == "window.vertical.open")
    #expect(widgetSnapshot.temperature == 64)
    #expect(widgetSnapshot.dewPoint == 52)
    #expect(widgetSnapshot.unitSymbol == "°F")
    #expect(widgetSnapshot.locationName == "Wilmington, DE")
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
        unitSymbol: "°F",
        fetchedAt: Date(timeIntervalSince1970: 1_800),
        locationName: "Wilmington, DE"
    )

    store.save(snapshot)

    #expect(store.load() == snapshot)
    #expect(snapshot.status.symbolName == "window.vertical.closed")
}
