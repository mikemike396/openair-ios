import Charts
import SwiftUI

struct ScheduleView: View {
    let snapshot: WeatherSnapshot
    let plan: RecommendationPlan
    let unit: TemperatureUnit
    var initialSelectedDate: Date? = nil

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    ForecastTimelineCard(
                        items: plan.hourly,
                        unit: unit,
                        initialSelectedDate: initialSelectedDate
                    )
                    HourlyDetailsCard(items: plan.hourly, unit: unit)
                }
                .padding()
            }
        }
        .navigationTitle("Forecast")
    }
}

private struct ForecastTimelineCard: View {
    let items: [(weather: HourlyWeather, recommendation: Recommendation)]
    let unit: TemperatureUnit
    let initialSelectedDate: Date?
    @State private var selectedItem: ForecastTimelineItem?

    private var chartItems: [ForecastTimelineItem] {
        Array(items.prefix(48)).map {
            ForecastTimelineItem(
                weather: $0.weather,
                status: $0.recommendation.status,
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
        .onAppear {
            guard selectedItem == nil else { return }
            selectedItem = chartItems.nearest(to: initialSelectedDate ?? Date())
        }
    }
}

private struct ForecastTimelineCharts: View {
    let items: [ForecastTimelineItem]
    @Binding var selectedItem: ForecastTimelineItem?
    let unit: TemperatureUnit

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
                unit: unit
            )
            .frame(height: 132)

            ForecastLineChart(
                title: "Dew point",
                metric: .dewPoint,
                items: items,
                selectedItem: $selectedItem,
                xDomain: xDomain,
                unit: unit
            )
            .frame(height: 132)

            ForecastStatusBand(items: items, xDomain: xDomain)
                .frame(height: 16)

            ForecastDayAxis(xDomain: xDomain)
                .frame(height: 22)
        }
    }
}

private struct ForecastLineChart: View {
    let title: String
    let metric: ForecastMetric
    let items: [ForecastTimelineItem]
    @Binding var selectedItem: ForecastTimelineItem?
    let xDomain: ClosedRange<Date>
    let unit: TemperatureUnit

    private var yDomain: ClosedRange<Double> {
        let values = items.map { metric.value(for: $0) }
        guard let minimum = values.min(), let maximum = values.max() else {
            return 40...80
        }

        let padding = max((maximum - minimum) * 0.18, 6)
        return (minimum - padding)...(maximum + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
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

        return "\(title) forecast chart from \(first.date.formatted(date: .omitted, time: .shortened)) to \(last.date.formatted(date: .abbreviated, time: .shortened))."
    }
}

private struct ForecastStatusBand: View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open and closed recommendation status over the forecast period")
    }

    private var statusSegments: [ForecastStatusSegment] {
        items.enumerated().map { index, item in
            ForecastStatusSegment(
                start: item.date,
                end: items[safe: index + 1]?.date ?? item.date.addingTimeInterval(60 * 60),
                status: item.status
            )
        }
    }
}

private struct ForecastDayAxis: View {
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
        .chartXAxis {
            AxisMarks(values: dayAxisValues) { value in
                AxisTick()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(dayAxisLabel(for: date))
                    }
                }
            }
        }
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
        .accessibilityHidden(true)
    }

    private var dayAxisValues: [Date] {
        let calendar = Calendar.current
        var values = [xDomain.lowerBound]
        var nextDay = calendar.startOfDay(for: xDomain.lowerBound)

        if nextDay <= xDomain.lowerBound {
            nextDay = calendar.date(byAdding: .day, value: 1, to: nextDay) ?? xDomain.upperBound
        }

        while nextDay < xDomain.upperBound {
            values.append(nextDay)
            guard let followingDay = calendar.date(byAdding: .day, value: 1, to: nextDay) else { break }
            nextDay = followingDay
        }

        return values
    }

    private func dayAxisLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}

private enum ForecastAxisMetrics {
    static let yLabelWidth: CGFloat = 34
}

private struct ForecastSelectionReadout: View {
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
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }
}

private struct ForecastTimelineLegend: View {
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

private struct HourlyDetailsCard: View {
    let items: [(weather: HourlyWeather, recommendation: Recommendation)]
    let unit: TemperatureUnit

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Hourly details")
                    .font(.title3.bold())

                VStack(spacing: 0) {
                    ForEach(Array(items.prefix(48).enumerated()), id: \.element.weather.id) { index, item in
                        NavigationLink {
                            HourDetailView(weather: item.weather, recommendation: item.recommendation, unit: unit)
                        } label: {
                            ForecastHourRow(item: item, unit: unit)
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

private struct ForecastHourRow: View {
    let item: (weather: HourlyWeather, recommendation: Recommendation)
    let unit: TemperatureUnit

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
                Text("\(unit.display(item.weather.temperatureFahrenheit))\(unit.symbol)")
                    .font(.subheadline.weight(.semibold))
                Text("DP \(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)")
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
        "\(item.weather.date.formatted(date: .abbreviated, time: .shortened)), \(item.recommendation.status.shortTitle), temperature \(unit.display(item.weather.temperatureFahrenheit))\(unit.symbol), dew point \(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)"
    }
}

private struct ForecastTimelineItem: Identifiable {
    let weather: HourlyWeather
    let status: RecommendationStatus
    let unit: TemperatureUnit

    var id: Date { weather.date }
    var date: Date { weather.date }
    var temperature: Double { unit.chartValue(weather.temperatureFahrenheit) }
    var dewPoint: Double { unit.chartValue(weather.dewPointFahrenheit) }
}

private struct ForecastStatusSegment: Identifiable {
    let start: Date
    let end: Date
    let status: RecommendationStatus

    var id: Date { start }
}

private enum ForecastMetric {
    case temperature
    case dewPoint

    var color: Color {
        switch self {
        case .temperature: Color.openAirAmber.opacity(0.75)
        case .dewPoint: Color.openAirBlue
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .temperature: 1.5
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

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Array where Element == ForecastTimelineItem {
    func nearest(to date: Date) -> ForecastTimelineItem? {
        min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
}

struct HourDetailView: View {
    let weather: HourlyWeather
    let recommendation: Recommendation
    let unit: TemperatureUnit

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 72))
                        .foregroundStyle(recommendation.status.color)
                    StatusPill(status: recommendation.status)
                    WeatherCard {
                        VStack(spacing: 12) {
                            LabeledContent("Temperature", value: "\(unit.display(weather.temperatureFahrenheit))\(unit.symbol)")
                            LabeledContent("Dew point", value: "\(unit.display(weather.dewPointFahrenheit))\(unit.symbol)")
                            LabeledContent("Rain chance", value: weather.precipitationChance, format: .percent)
                            LabeledContent("Wind", value: "\(Int(weather.windMPH.rounded())) mph")
                            if let gustMPH = weather.gustMPH {
                                LabeledContent("Gusts", value: "\(Int(gustMPH.rounded())) mph")
                            }
                        }
                    }
                    WeatherCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Why")
                                .font(.headline)
                            ForEach(recommendation.reasons, id: \.self) {
                                Label($0.label, systemImage: $0.symbol)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(weather.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
