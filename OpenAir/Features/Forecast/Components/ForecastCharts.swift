import Charts
import SwiftUI

enum ForecastAxisMetrics {
    static let yLabelWidth: CGFloat = 34
}

enum ForecastMetric {
    case temperature
    case dewPoint

    var color: Color {
        switch self {
        case .temperature: .openAirAmber
        case .dewPoint: .openAirBlue
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

    func referenceLines(
        for preferences: ComfortPreferences,
        unit: TemperatureUnit
    ) -> [ForecastReferenceLine] {
        switch self {
        case .temperature:
            [
                ForecastReferenceLine(
                    accessibilityLabel: "minimum comfort temperature",
                    value: unit.chartValue(preferences.idealMinimumFahrenheit)
                ),
                ForecastReferenceLine(
                    accessibilityLabel: "maximum comfort temperature",
                    value: unit.chartValue(preferences.idealMaximumFahrenheit)
                )
            ]
        case .dewPoint:
            [
                ForecastReferenceLine(
                    accessibilityLabel: "maximum comfortable dew point",
                    value: unit.chartValue(preferences.maximumDewPointFahrenheit)
                )
            ]
        }
    }
}

struct ForecastLineChart: View {
    let data: ForecastLineChartData
    let items: [ForecastTimelineItem]
    let selectedItem: ForecastTimelineItem?
    @Binding var selectedDate: Date?
    let xDomain: ClosedRange<Date>
    let unit: TemperatureUnit

    private var persistentSelectedDate: Binding<Date?> {
        Binding(
            get: { selectedDate },
            set: { newDate in
                guard let newDate else { return }
                selectedDate = newDate
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(data.referenceLines) { referenceLine in
                    RuleMark(y: .value("Comfort threshold", referenceLine.value))
                        .foregroundStyle(data.metric.color.opacity(0.65))
                        .lineStyle(.init(lineWidth: 1.25, dash: [4, 3]))
                }

                ForEach(items) { item in
                    LineMark(
                        x: .value("Time", item.date),
                        y: .value(data.title, data.metric.value(for: item))
                    )
                    .foregroundStyle(data.metric.color)
                    .lineStyle(.init(lineWidth: data.metric.lineWidth, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let selectedItem {
                    RuleMark(x: .value("Selected time", selectedItem.date))
                        .foregroundStyle(Color.primary.opacity(0.55))
                        .lineStyle(.init(lineWidth: 1.2))

                    PointMark(
                        x: .value("Selected time", selectedItem.date),
                        y: .value(data.title, data.metric.value(for: selectedItem))
                    )
                    .foregroundStyle(data.metric.color)
                    .symbolSize(48)
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: data.yDomain)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    if let temperature = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(temperature.rounded()))\(unit.symbol)")
                                .frame(width: ForecastAxisMetrics.yLabelWidth, alignment: .trailing)
                        }
                    }
                }
            }
            .chartXSelection(value: persistentSelectedDate)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(data.accessibilitySummary)
        }
    }
}

struct ForecastStatusBand: View {
    let segments: [ForecastStatusSegment]
    let xDomain: ClosedRange<Date>

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: ForecastAxisMetrics.yLabelWidth)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))

                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.status.color)
                            .frame(
                                width: segmentWidth(segment, totalWidth: geometry.size.width),
                                height: geometry.size.height
                            )
                            .offset(
                                x: position(for: segment.start, totalWidth: geometry.size.width)
                            )
                    }

                    ForEach(
                        ForecastDayBoundary.boundaries(
                            for: xDomain,
                            width: geometry.size.width
                        )
                    ) { boundary in
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: max(geometry.size.height - 5, 0))
                            .offset(x: boundary.position)
                    }
                }
                .clipShape(.capsule)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open and closed recommendation status over the forecast period")
    }

    private func segmentWidth(
        _ segment: ForecastStatusSegment,
        totalWidth: CGFloat
    ) -> CGFloat {
        max(
            position(for: segment.end, totalWidth: totalWidth)
                - position(for: segment.start, totalWidth: totalWidth),
            0
        )
    }

    private func position(for date: Date, totalWidth: CGFloat) -> CGFloat {
        let duration = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
        guard duration > 0 else { return 0 }

        let fraction = date.timeIntervalSince(xDomain.lowerBound) / duration
        return totalWidth * min(max(fraction, 0), 1)
    }
}

struct ForecastDayAxis: View {
    let xDomain: ClosedRange<Date>
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: ForecastAxisMetrics.yLabelWidth)

            Group {
                ForEach(labels) { label in
                    Text(label.text)
                        .frame(width: 44)
                        .position(x: label.position, y: 11)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                availableWidth = newWidth
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    private var labels: [ForecastDayAxisLabel] {
        ForecastDayAxisLabel.labels(for: xDomain, width: availableWidth)
    }
}
