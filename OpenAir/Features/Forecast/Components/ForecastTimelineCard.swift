import SwiftUI

struct ForecastTimelineCard: View {
    let items: [(weather: HourlyWeather, recommendation: Recommendation)]
    let unit: TemperatureUnit
    let preferences: ComfortPreferences
    let initialSelectedDate: Date?
    @State private var selectedItem: ForecastTimelineItem?

    private var chartItems: [ForecastTimelineItem] {
        Array(items.prefix(48)).map {
            ForecastTimelineItem(
                weather: $0.weather,
                status: $0.recommendation.status,
                reasons: $0.recommendation.reasons,
                unit: unit
            )
        }
    }

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("48-hour outlook")
                        .font(.title3.bold())
                    Text("Temperature, dew point, and window status")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if chartItems.count > 1 {
                    if let selectedItem {
                        ForecastSelectionReadout(item: selectedItem, unit: unit)
                    }

                    ForecastTimelineCharts(
                        items: chartItems,
                        selectedItem: $selectedItem,
                        unit: unit,
                        preferences: preferences
                    )
                    ForecastTimelineLegend()
                } else {
                    ContentUnavailableView(
                        "Forecast unavailable",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Hourly weather is not available yet.")
                    )
                    .frame(minHeight: 220)
                }
            }
        }
        .onAppear {
            guard selectedItem == nil else { return }
            selectedItem = chartItems.nearest(to: initialSelectedDate ?? Date())
        }
    }
}

struct ForecastTimelineCharts: View {
    let items: [ForecastTimelineItem]
    @Binding var selectedItem: ForecastTimelineItem?
    let unit: TemperatureUnit
    let preferences: ComfortPreferences

    private var xDomain: ClosedRange<Date> {
        let first = items.first?.date ?? Date()
        let last = items.last?.date.addingTimeInterval(60 * 60) ?? first.addingTimeInterval(60 * 60)
        return first...last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForecastLineChart(
                title: "Temperature",
                metric: .temperature,
                items: items,
                selectedItem: $selectedItem,
                xDomain: xDomain,
                unit: unit,
                preferences: preferences
            )
            .frame(height: 132)

            ForecastLineChart(
                title: "Dew point",
                metric: .dewPoint,
                items: items,
                selectedItem: $selectedItem,
                xDomain: xDomain,
                unit: unit,
                preferences: preferences
            )
            .frame(height: 132)

            ForecastStatusBand(items: items, xDomain: xDomain)
                .frame(height: 16)

            ForecastDayAxis(xDomain: xDomain)
                .frame(height: 22)
        }
    }
}
