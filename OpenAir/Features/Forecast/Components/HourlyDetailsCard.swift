import SwiftUI

struct HourlyDetailsCard: View {
    let items: [(weather: HourlyWeather, recommendation: Recommendation)]
    let unit: TemperatureUnit
    let temperatureSource: TemperatureEvaluationSource

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Hourly details")
                    .font(.title3.bold())

                LazyVStack(spacing: 0) {
                    ForEach(Array(items.prefix(48).enumerated()), id: \.element.weather.id) { index, item in
                        NavigationLink {
                            HourDetailView(
                                weather: item.weather,
                                recommendation: item.recommendation,
                                unit: unit,
                                temperatureSource: temperatureSource
                            )
                        } label: {
                            CellView(item: item, unit: unit, temperatureSource: temperatureSource)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if index < min(items.count, 48) - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct CellView: View {
    let item: (weather: HourlyWeather, recommendation: Recommendation)
    let unit: TemperatureUnit
    let temperatureSource: TemperatureEvaluationSource

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.weather.symbolName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.weather.date, format: .dateTime.weekday().hour())
                    .font(.subheadline.weight(.semibold))
                Text(item.recommendation.status.shortTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(item.recommendation.status.color)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(unit.display(item.weather.temperatureFahrenheit(for: temperatureSource)))\(unit.symbol)")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 3) {
                    Image(systemName: "drop")
                        .foregroundStyle(Color(.openAirBlue))
                    Text("\(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)")
                }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        [
            item.weather.date.formatted(date: .abbreviated, time: .shortened),
            item.recommendation.status.shortTitle,
            "\(temperatureSource.temperatureLabel.lowercased()) \(unit.display(item.weather.temperatureFahrenheit(for: temperatureSource)))\(unit.symbol)",
            "dew point \(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)"
        ]
        .joined(separator: ", ")
    }
}
