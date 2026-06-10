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
    let title: String
    let metric: ForecastMetric
    let items: [ForecastTimelineItem]
    @Binding var selectedItem: ForecastTimelineItem?
    let xDomain: ClosedRange<Date>
    let unit: TemperatureUnit
    let preferences: ComfortPreferences

    private var referenceLines: [ForecastReferenceLine] {
        metric.referenceLines(for: preferences, unit: unit)
    }

    private var yDomain: ClosedRange<Double> {
        ForecastChartScale.domain(
            values: items.map { metric.value(for: $0) },
            referenceValues: referenceLines.map(\.value)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(referenceLines) { referenceLine in
                    RuleMark(y: .value("Comfort threshold", referenceLine.value))
                        .foregroundStyle(metric.color.opacity(0.65))
                        .lineStyle(.init(lineWidth: 1.25, dash: [4, 3]))
                }

                ForEach(items) { item in
                    LineMark(
                        x: .value("Time", item.date),
                        y: .value(title, metric.value(for: item))
                    )
                    .foregroundStyle(metric.color)
                    .lineStyle(.init(lineWidth: metric.lineWidth, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let selectedItem {
                    RuleMark(x: .value("Selected time", selectedItem.date))
                        .foregroundStyle(Color.primary.opacity(0.55))
                        .lineStyle(.init(lineWidth: 1.2))

                    PointMark(
                        x: .value("Selected time", selectedItem.date),
                        y: .value(title, metric.value(for: selectedItem))
                    )
                    .foregroundStyle(metric.color)
                    .symbolSize(48)
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
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
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectItem(at: value.location, proxy: proxy, geometry: geometry)
                                }
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    private func selectItem(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plotArea = geometry[plotFrame]
        let xPosition = location.x - plotArea.origin.x
        guard
            xPosition >= 0,
            xPosition <= plotArea.width,
            let date = proxy.value(atX: xPosition, as: Date.self)
        else {
            return
        }

        selectedItem = items.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    private var accessibilitySummary: String {
        guard let first = items.first, let last = items.last else {
            return "\(title) forecast chart unavailable"
        }

        let thresholds = referenceLines.map {
            "\($0.accessibilityLabel) \(Int($0.value.rounded()))\(unit.symbol)"
        }
        .joined(separator: ", ")

        return "\(title) forecast chart from \(first.date.formatted(date: .omitted, time: .shortened)) to \(last.date.formatted(date: .abbreviated, time: .shortened)). Comfort thresholds: \(thresholds)."
    }
}

struct ForecastStatusBand: View {
    let items: [ForecastTimelineItem]
    let xDomain: ClosedRange<Date>

    var body: some View {
        Chart {
            ForEach(statusSegments) { segment in
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
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 1, height: plotArea.height)
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

    private var statusSegments: [ForecastStatusSegment] {
        ForecastStatusSegment.segments(for: items)
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
