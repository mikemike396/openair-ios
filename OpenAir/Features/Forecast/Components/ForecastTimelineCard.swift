import SwiftUI

struct ForecastTimelineCard: View {
    private let chartData: ForecastChartData
    let unit: TemperatureUnit
    let initialSelectedDate: Date?

    init(
        items: [(weather: HourlyWeather, recommendation: Recommendation)],
        unit: TemperatureUnit,
        preferences: ComfortPreferences,
        initialSelectedDate: Date?
    ) {
        self.chartData = ForecastChartData(
            items: items,
            unit: unit,
            preferences: preferences
        )
        self.unit = unit
        self.initialSelectedDate = initialSelectedDate
    }

    var body: some View {
        WeatherCard {
            ForecastTimelineContent(
                chartData: chartData,
                unit: unit,
                initialSelectedDate: initialSelectedDate
            )
        }
    }
}

private struct ForecastTimelineContent: View {
    let chartData: ForecastChartData
    let unit: TemperatureUnit
    @State private var selectedDate: Date?

    init(
        chartData: ForecastChartData,
        unit: TemperatureUnit,
        initialSelectedDate: Date?
    ) {
        self.chartData = chartData
        self.unit = unit
        _selectedDate = State(
            initialValue: chartData.nearestItem(to: initialSelectedDate ?? .now)?.date
        )
    }

    var body: some View {
        let selectedItem = chartData.nearestItem(to: selectedDate)

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("48-hour outlook")
                    .font(.title3.bold())
                Text("Temperature, dew point, and window status")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if chartData.items.count > 1 {
                if let selectedItem {
                    ForecastSelectionReadout(item: selectedItem, unit: unit)
                }

                ForecastTimelineCharts(
                    chartData: chartData,
                    selectedItem: selectedItem,
                    selectedDate: $selectedDate,
                    unit: unit
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
}

struct ForecastTimelineCharts: View {
    let chartData: ForecastChartData
    let selectedItem: ForecastTimelineItem?
    @Binding var selectedDate: Date?
    let unit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForecastLineChart(
                data: chartData.temperature,
                items: chartData.items,
                selectedItem: selectedItem,
                selectedDate: $selectedDate,
                xDomain: chartData.xDomain,
                unit: unit
            )
            .frame(height: 132)

            ForecastLineChart(
                data: chartData.dewPoint,
                items: chartData.items,
                selectedItem: selectedItem,
                selectedDate: $selectedDate,
                xDomain: chartData.xDomain,
                unit: unit
            )
            .frame(height: 132)

            ForecastStatusBand(
                segments: chartData.statusSegments,
                xDomain: chartData.xDomain
            )
                .frame(height: 16)

            ForecastDayAxis(xDomain: chartData.xDomain)
                .frame(height: 22)
        }
    }
}
