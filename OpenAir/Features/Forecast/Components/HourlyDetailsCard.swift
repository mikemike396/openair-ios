import SwiftUI

struct HourlyDetailsCard: View {
    let items: [(weather: HourlyWeather, recommendation: Recommendation)]
    let unit: TemperatureUnit
    let temperatureSource: TemperatureEvaluationSource
    private let days: [HourlyDetailsDay]
    private let temperatureDomain: ClosedRange<Double>?
    private let dewPointDomain: ClosedRange<Double>?
    @State private var expandedDayIDs: Set<Date>

    init(
        items: [(weather: HourlyWeather, recommendation: Recommendation)],
        unit: TemperatureUnit,
        temperatureSource: TemperatureEvaluationSource
    ) {
        self.items = items
        self.unit = unit
        self.temperatureSource = temperatureSource
        let days = HourlyDetailsDay.groups(for: items)
        self.days = days
        temperatureDomain = Self.domain(
            for: items.map { $0.weather.temperatureFahrenheit(for: temperatureSource) }
        )
        dewPointDomain = Self.domain(for: items.map(\.weather.dewPointFahrenheit))
        _expandedDayIDs = State(initialValue: [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Forecast details")
                .font(.title3.bold())

            WeatherCard(contentPadding: 16) {
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        if index > 0 {
                            Divider()
                        }

                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedDayIDs.contains(day.id) },
                                set: { isExpanded in
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        if isExpanded {
                                            expandedDayIDs.insert(day.id)
                                        } else {
                                            expandedDayIDs.remove(day.id)
                                        }
                                    }
                                }
                            )
                        ) {
                            ForEach(Array(day.items.enumerated()), id: \.element.weather.id) { index, item in
                                NavigationLink {
                                    HourDetailView(
                                        weather: item.weather,
                                        recommendation: item.recommendation,
                                        unit: unit,
                                        temperatureSource: temperatureSource
                                    )
                                } label: {
                                    CellView(item: item, unit: unit, temperatureSource: temperatureSource)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if index < day.items.count - 1 {
                                    Divider()
                                }
                            }
                        } label: {
                            DayHeader(
                                day: day,
                                unit: unit,
                                temperatureSource: temperatureSource,
                                temperatureDomain: temperatureDomain,
                                dewPointDomain: dewPointDomain
                            )
                            .padding(.vertical, 10)
                        }
                        .tint(Color(uiColor: .label))
                        .transaction { transaction in
                            transaction.disablesAnimations = true
                        }
                    }
                }
            }
        }
    }

    private static func domain(for values: [Double]) -> ClosedRange<Double>? {
        guard let minimum = values.min(), let maximum = values.max() else { return nil }
        return minimum...maximum
    }
}

private struct DayHeader: View {
    let day: HourlyDetailsDay
    let unit: TemperatureUnit
    let temperatureSource: TemperatureEvaluationSource
    let temperatureDomain: ClosedRange<Double>?
    let dewPointDomain: ClosedRange<Double>?

    private var temperatures: [Double] {
        day.items.map { $0.weather.temperatureFahrenheit(for: temperatureSource) }
    }

    private var dewPoints: [Double] {
        day.items.map(\.weather.dewPointFahrenheit)
    }

    private var dayLabel: String {
        if Calendar.current.isDateInToday(day.date) {
            return "Today"
        }
        return day.date.formatted(.dateTime.weekday(.abbreviated))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(dayLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .label))
                .frame(width: 46, alignment: .leading)

            VStack(spacing: 8) {
                if let temperatureLow = temperatures.min(),
                   let temperatureHigh = temperatures.max(),
                   let dewPointLow = dewPoints.min(),
                   let dewPointHigh = dewPoints.max()
                {
                    MetricRangeRow(
                        lower: temperatureLow,
                        upper: temperatureHigh,
                        domain: temperatureDomain,
                        color: .openAirAmber,
                        unit: unit,
                        symbol: "thermometer.medium"
                    )
                    MetricRangeRow(
                        lower: dewPointLow,
                        upper: dewPointHigh,
                        domain: dewPointDomain,
                        color: .openAirBlue,
                        unit: unit,
                        symbol: "drop"
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MetricRangeRow: View {
    let lower: Double
    let upper: Double
    let domain: ClosedRange<Double>?
    let color: Color
    let unit: TemperatureUnit
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 14)

            Text("\(unit.display(lower))°")
                .frame(width: 32, alignment: .trailing)

            RangeTrack(
                lower: lower,
                upper: upper,
                domain: domain,
                color: color
            )

            Text("\(unit.display(upper))°")
                .frame(width: 32, alignment: .leading)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .monospacedDigit()
    }
}

private struct RangeTrack: View {
    @Environment(\.colorScheme) private var colorScheme

    let lower: Double
    let upper: Double
    let domain: ClosedRange<Double>?
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = proxy.size.width
            let positions = positions(in: trackWidth)

            Capsule()
                .fill(trackColor)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: positions.width)
                        .offset(x: positions.start)
                }
        }
        .frame(height: 6)
    }

    private var trackColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.14)
            : Color(.openAirNavy).opacity(0.10)
    }

    private func positions(in trackWidth: CGFloat) -> (start: CGFloat, width: CGFloat) {
        guard let domain else { return (0, 0) }
        let span = domain.upperBound - domain.lowerBound
        guard span > 0 else { return ((trackWidth - 8) / 2, 8) }

        let start = CGFloat((lower - domain.lowerBound) / span) * trackWidth
        let end = CGFloat((upper - domain.lowerBound) / span) * trackWidth
        let width = min(max(8, end - start), trackWidth)
        return (min(start, max(trackWidth - width, 0)), width)
    }
}

private struct CellView: View {
    let item: (weather: HourlyWeather, recommendation: Recommendation)
    let unit: TemperatureUnit
    let temperatureSource: TemperatureEvaluationSource

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
                Text("\(unit.display(item.weather.temperatureFahrenheit(for: temperatureSource)))\(unit.symbol)")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 3) {
                    Image(systemName: "drop")
                        .foregroundStyle(Color(.openAirBlue))
                    Text("\(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)")
                }
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
        [
            item.weather.date.formatted(date: .abbreviated, time: .shortened),
            item.recommendation.status.shortTitle,
            "\(temperatureSource.temperatureLabel.lowercased()) \(unit.display(item.weather.temperatureFahrenheit(for: temperatureSource)))\(unit.symbol)",
            "dew point \(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)"
        ]
        .joined(separator: ", ")
    }
}
