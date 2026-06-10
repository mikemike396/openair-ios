import SwiftUI

struct HourlyList: View {
    let plan: RecommendationPlan
    let preferences: ComfortPreferences
    private let cardHorizontalPadding: CGFloat = 20

    private var unit: TemperatureUnit {
        preferences.temperatureUnit
    }

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Next few hours")
                    .font(.title3.bold())

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(Array(plan.hourly.prefix(16).enumerated()), id: \.element.weather.id) { index, item in
                            NavigationLink {
                                ForecastView(
                                    plan: plan,
                                    preferences: preferences,
                                    initialSelectedDate: item.weather.date
                                )
                            } label: {
                                HourlyTile(item: item, index: index, unit: unit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, cardHorizontalPadding)
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, -cardHorizontalPadding)
            }
        }
    }
}

private struct HourlyTile: View {
    let item: (weather: HourlyWeather, recommendation: Recommendation)
    let index: Int
    let unit: TemperatureUnit

    var body: some View {
        VStack(spacing: 10) {
            Text(index == 0 ? "Now" : item.weather.date.formatted(.dateTime.hour()))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Image(systemName: item.weather.symbolName)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(height: 28)

            VStack(spacing: 4) {
                Text("\(unit.display(item.weather.temperatureFahrenheit))\(unit.symbol)")
                    .font(.headline.weight(.semibold))
                Text("DP \(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
        .frame(width: 58, height: 108)
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let time = index == 0 ? "Now" : item.weather.date.formatted(date: .omitted, time: .shortened)
        return "\(time), temperature \(unit.display(item.weather.temperatureFahrenheit))\(unit.symbol), dew point \(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)"
    }
}
