import Testing
@testable import OpenAir

@Suite
struct ComfortPreferencesTests {
    @Test
    func normalizedClampsWeatherThresholdPreferencesToConfigurableRanges() {
        var preferences = ComfortPreferences.default(for: .init(identifier: "en_US"))
        preferences.idealMinimumFahrenheit = 0
        preferences.idealMaximumFahrenheit = 100
        preferences.maximumDewPointFahrenheit = 100
        preferences.maximumRainChance = 1
        preferences.maximumWindMPH = 0
        preferences.maximumGustMPH = 100

        let normalized = preferences.normalized

        #expect(normalized.idealMinimumFahrenheit == .minimumConfigurableTemperatureFahrenheit)
        #expect(normalized.idealMaximumFahrenheit == .maximumConfigurableTemperatureFahrenheit)
        #expect(normalized.maximumDewPointFahrenheit == .maximumConfigurableDewPointFahrenheit)
        #expect(normalized.maximumRainChance == .maximumConfigurableRainChance)
        #expect(normalized.maximumWindMPH == .minimumConfigurableWindMPH)
        #expect(normalized.maximumGustMPH == .maximumConfigurableGustMPH)
    }

    @Test
    func normalizedRaisesGustPreferenceToConfigurableMinimum() {
        var preferences = ComfortPreferences.default(for: .init(identifier: "en_US"))
        preferences.maximumGustMPH = 0

        #expect(preferences.normalized.maximumGustMPH == .minimumConfigurableGustMPH)
    }
    
    @Test
    func normalizedClampsTemperaturesBeforeFixingInvertedRange() {
        var preferences = ComfortPreferences.default(for: .init(identifier: "en_US"))
        preferences.idealMinimumFahrenheit = 90
        preferences.idealMaximumFahrenheit = 60

        let normalized = preferences.normalized

        #expect(normalized.idealMinimumFahrenheit == .maximumConfigurableIdealMinimumFahrenheit)
        #expect(normalized.idealMaximumFahrenheit == .maximumConfigurableIdealMinimumFahrenheit)
    }
}
