import SwiftUI

struct HourDetailView: View {
    let weather: HourlyWeather
    let recommendation: Recommendation
    let unit: TemperatureUnit

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: weather.symbolName)
                    .font(.system(size: 72))
                    .foregroundStyle(recommendation.status.color)
                StatusView(status: recommendation.status)
                WeatherCard {
                    VStack(spacing: 12) {
                        LabeledContent("Temperature", value: "\(unit.display(weather.temperatureFahrenheit))\(unit.symbol)")
                        LabeledContent("Dew point", value: "\(unit.display(weather.dewPointFahrenheit))\(unit.symbol)")
                        LabeledContent("Rain chance", value: weather.precipitationChance, format: .percent)
                        LabeledContent("Wind", value: "\(Int(weather.windMPH.rounded())) mph")
                        if let gustMPH = weather.gustMPH {
                            LabeledContent("Gusts", value: "\(Int(gustMPH.rounded())) mph")
                        }
                    }
                }
                WeatherCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why")
                            .font(.headline)
                        ForEach(recommendation.reasons, id: \.self) {
                            Label($0.label, systemImage: $0.symbol)
                        }
                    }
                }
                WeatherAttributionView()
            }
            .padding()
        }
        .navigationTitle(weather.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
    }
}

private struct StatusView: View {
    let status: RecommendationStatus

    var body: some View {
        Label(status.shortTitle, systemImage: status.symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(status.color.opacity(0.12), in: .capsule)
            .accessibilityLabel("Recommendation: \(status.shortTitle)")
    }
}
