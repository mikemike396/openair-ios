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
        Chart {
            ForEach(segments) { segment in
                RectangleMark(
                    xStart: .value("Start", segment.start),
                    xEnd: .value("End", segment.end),
                    yStart: .value("Status band", 0),
                    yEnd: .value("Status band", 1)
                )
                .foregroundStyle(segment.status.color)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0]) {
                AxisTick().foregroundStyle(.clear)
                AxisValueLabel {
                    Text("000\(TemperatureUnit.fahrenheit.symbol)")
                        .frame(width: ForecastAxisMetrics.yLabelWidth, alignment: .trailing)
                        .hidden()
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.secondary.opacity(0.12), in: .capsule)
                .clipShape(.capsule)
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plotArea = geometry[plotFrame]
                    ForEach(ForecastDayBoundary.boundaries(for: xDomain, width: plotArea.width)) { boundary in
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: plotArea.height - 5)
                            .position(
                                x: plotArea.minX + boundary.position,
                                y: plotArea.midY
                            )
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open and closed recommendation status over the forecast period")
    }
}

struct ForecastDayAxis: View {
    let xDomain: ClosedRange<Date>

    var body: some View {
        Chart {
            PointMark(
                x: .value("Start", xDomain.lowerBound),
                y: .value("Axis", 0)
            )
            .foregroundStyle(.clear)
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0]) {
                AxisTick().foregroundStyle(.clear)
                AxisValueLabel {
                    Text("000\(TemperatureUnit.fahrenheit.symbol)")
                        .frame(width: ForecastAxisMetrics.yLabelWidth, alignment: .trailing)
                        .hidden()
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plotArea = geometry[plotFrame]
                    ForEach(ForecastDayAxisLabel.labels(for: xDomain, width: plotArea.width)) { label in
                        Text(label.text)
                            .frame(width: 44)
                            .position(
                                x: plotArea.minX + label.position,
                                y: plotArea.midY
                            )
                    }
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}
