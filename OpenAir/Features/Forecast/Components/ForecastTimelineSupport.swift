import SwiftUI

enum ForecastAxisMetrics {
    static let yLabelWidth: CGFloat = 34
}

struct ForecastSelectionReadout: View {
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
            Label("DP \(Int(item.dewPoint.rounded()))\(unit.symbol)", systemImage: "drop")
        }
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .panel(cornerRadius: 12)
    }
}

struct ForecastTimelineLegend: View {
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
        LineLegendItem(label: "Dew point", color: .openAirBlue, lineWidth: 5)
        LineLegendItem(label: "Temperature", color: .openAirAmber, lineWidth: 2)
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

struct ForecastTimelineItem: Identifiable {
    let weather: HourlyWeather
    let status: RecommendationStatus
    let unit: TemperatureUnit

    var id: Date { weather.date }
    var date: Date { weather.date }
    var temperature: Double { unit.chartValue(weather.temperatureFahrenheit) }
    var dewPoint: Double { unit.chartValue(weather.dewPointFahrenheit) }
}

struct ForecastStatusSegment: Identifiable {
    let start: Date
    let end: Date
    let status: RecommendationStatus

    var id: Date { start }
}

enum ForecastMetric {
    case temperature
    case dewPoint

    var color: Color {
        switch self {
        case .temperature: Color.openAirAmber
        case .dewPoint: Color.openAirBlue
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .temperature: 2.25
        case .dewPoint: 3.5
        }
    }

    func value(for item: ForecastTimelineItem) -> Double {
        switch self {
        case .temperature: item.temperature
        case .dewPoint: item.dewPoint
        }
    }
}

private extension TemperatureUnit {
    func chartValue(_ fahrenheit: Double) -> Double {
        switch self {
        case .fahrenheit: fahrenheit
        case .celsius: (fahrenheit - 32) * 5 / 9
        }
    }
}

extension Array where Element == ForecastTimelineItem {
    func nearest(to date: Date) -> ForecastTimelineItem? {
        min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
}
