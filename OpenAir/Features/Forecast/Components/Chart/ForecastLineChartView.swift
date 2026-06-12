import Charts
import SwiftUI

enum ForecastAxisMetrics {
    static let yLabelWidth: CGFloat = 34
    static let plotLeadingInset: CGFloat = yLabelWidth + 8
}

struct ForecastLineChartView: View {
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
