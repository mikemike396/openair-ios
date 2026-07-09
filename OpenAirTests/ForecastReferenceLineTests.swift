import Testing
@testable import OpenAir

@Suite
struct ForecastReferenceLineTests {
    @Test
    func temperatureReferencesUseConfiguredMinimumAndMaximum() {
        var preferences = ComfortPreferences()
        preferences.idealMinimumFahrenheit = 54
        preferences.idealMaximumFahrenheit = 76

        let references = ForecastMetric.temperature.referenceLines(
            for: preferences,
            unit: .fahrenheit
        )

        #expect(references.map(\.value) == [54, 76])
    }

    @Test
    func dewPointReferenceUsesConfiguredMaximum() {
        var preferences = ComfortPreferences()
        preferences.maximumDewPointFahrenheit = 61

        let references = ForecastMetric.dewPoint.referenceLines(
            for: preferences,
            unit: .fahrenheit
        )

        #expect(references.map(\.value) == [61])
    }

    @Test
    func referencesConvertToCelsius() {
        var preferences = ComfortPreferences()
        preferences.idealMinimumFahrenheit = 50
        preferences.idealMaximumFahrenheit = 68
        preferences.maximumDewPointFahrenheit = 59

        let temperatureReferences = ForecastMetric.temperature.referenceLines(
            for: preferences,
            unit: .celsius
        )
        let dewPointReferences = ForecastMetric.dewPoint.referenceLines(
            for: preferences,
            unit: .celsius
        )

        #expect(temperatureReferences[0].value == 10)
        #expect(temperatureReferences[1].value == 20)
        #expect(dewPointReferences[0].value == 15)
    }

    @Test
    func chartDomainIncludesForecastValuesAndReferences() {
        let domain = ForecastChartScale.domain(
            values: [65, 70, 72],
            referenceValues: [52, 78]
        )

        #expect(domain.lowerBound < 52)
        #expect(domain.upperBound > 78)
    }
}
