import SwiftUI

struct ForecastTimelineCard: View {
    private let chartData: ForecastChartData
    let unit: TemperatureUnit
    let initialSelectedDate: Date?
    let rangeTitle: String

    init(
        items: [(weather: HourlyWeather, recommendation: Recommendation)],
        unit: TemperatureUnit,
        preferences: ComfortPreferences,
        initialSelectedDate: Date?,
        rangeTitle: String
    ) {
        self.chartData = ForecastChartData(
            items: items,
            unit: unit,
            preferences: preferences
        )
        self.unit = unit
        self.initialSelectedDate = initialSelectedDate
        self.rangeTitle = rangeTitle
    }

    var body: some View {
        WeatherCard {
            Content(
                chartData: chartData,
                unit: unit,
                initialSelectedDate: initialSelectedDate,
                rangeTitle: rangeTitle
            )
        }
    }
}

private struct Content: View {
    let chartData: ForecastChartData
    let unit: TemperatureUnit
    let rangeTitle: String
    @State private var selectedDate: Date?

    init(
        chartData: ForecastChartData,
        unit: TemperatureUnit,
        initialSelectedDate: Date?,
        rangeTitle: String
    ) {
        self.chartData = chartData
        self.unit = unit
        self.rangeTitle = rangeTitle
        _selectedDate = State(
            initialValue: chartData.nearestItem(to: initialSelectedDate ?? .now)?.date
        )
    }

    var body: some View {
        let selectedItem = chartData.nearestItem(to: selectedDate)

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(rangeTitle) outlook")
                    .font(.title3.bold())
                Text(dateRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if chartData.items.count > 1 {
                if let selectedItem {
                    SelectionReadout(item: selectedItem, unit: unit)
                }

                LineCharts(
                    chartData: chartData,
                    selectedItem: selectedItem,
                    selectedDate: $selectedDate,
                    unit: unit
                )
                TimelineLegend()
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

    private var dateRangeText: String {
        guard let firstDate = chartData.items.first?.date,
              let lastDate = chartData.items.last?.date
        else {
            return ""
        }

        let format = Date.FormatStyle().month(.abbreviated).day()
        return "\(firstDate.formatted(format)) – \(lastDate.formatted(format))"
    }
}

private struct SelectionReadout: View {
    let item: ForecastTimelineItem
    let unit: TemperatureUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.date, format: .dateTime.weekday().hour())
                    .font(.subheadline.weight(.semibold))
                Text(item.status.shortTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(item.status.color)
            }

            Spacer()

            Label("\(Int(item.temperature.rounded()))\(unit.symbol)", systemImage: "thermometer.medium")
            Label {
                Text("\(Int(item.dewPoint.rounded()))\(unit.symbol)")
            } icon: {
                Image(systemName: "drop")
                    .foregroundStyle(Color(.openAirBlue))
            }
        }
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .panel(cornerRadius: 12)
    }
}

private struct LineCharts: View {
    let chartData: ForecastChartData
    let selectedItem: ForecastTimelineItem?
    @Binding var selectedDate: Date?
    let unit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForecastLineChartView(
                data: chartData.temperature,
                items: chartData.items,
                selectedItem: selectedItem,
                selectedDate: $selectedDate,
                xDomain: chartData.xDomain,
                unit: unit
            )
            .frame(height: 132)

            ForecastLineChartView(
                data: chartData.dewPoint,
                items: chartData.items,
                selectedItem: selectedItem,
                selectedDate: $selectedDate,
                xDomain: chartData.xDomain,
                unit: unit
            )
            .frame(height: 132)

            ForecastStatusBandView(
                segments: chartData.statusSegments,
                xDomain: chartData.xDomain
            )
            .frame(height: 16)

            ForecastDayAxisView(
                xDomain: chartData.xDomain
            )
            .frame(height: 20)
        }
    }
}

private struct TimelineLegend: View {
    var body: some View {
        ViewThatFits {
            HStack(spacing: 14) {
                legendItems
            }
            VStack(alignment: .leading, spacing: 10) {
                legendItems
            }
        }
        .font(.caption.weight(.medium))
    }

    @ViewBuilder
    private var legendItems: some View {
        LineLegendItem(label: "Temperature", color: .openAirAmber, lineWidth: 2)
        LineLegendItem(label: "Dew point", color: .openAirBlue, lineWidth: 5)
        ReferenceLegendItem(label: "Temperature comfort range", color: .openAirAmber)
        ReferenceLegendItem(label: "Maximum dew point", color: .openAirBlue)
        StatusLegendItem(label: "Open window", status: .open)
        StatusLegendItem(label: "Keep closed", status: .keepClosed)
    }
}


private struct LineLegendItem: View {
    let label: String
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Label {
            Text(label)
        } icon: {
            Capsule()
                .fill(color)
                .frame(width: 22, height: lineWidth)
        }
        .foregroundStyle(.secondary)
    }
}

private struct ReferenceLegendItem: View {
    let label: String
    let color: Color

    var body: some View {
        Label {
            Text(label)
        } icon: {
            Capsule()
                .stroke(
                    color.opacity(0.65),
                    style: StrokeStyle(lineWidth: 1.25, dash: [4, 3])
                )
                .frame(width: 22, height: 2)
        }
        .foregroundStyle(.secondary)
    }
}

private struct StatusLegendItem: View {
    let label: String
    let status: RecommendationStatus

    var body: some View {
        Label {
            Text(label)
        } icon: {
            RoundedRectangle(cornerRadius: 3)
                .fill(status.color)
                .frame(width: 18, height: 10)
        }
        .foregroundStyle(.secondary)
    }
}
