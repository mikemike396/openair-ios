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
        LineLegendItem(label: "Temperature", color: .openAirAmber, lineWidth: 2)
        LineLegendItem(label: "Dew point", color: .openAirBlue, lineWidth: 5)
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
    let reasons: [RecommendationReason]
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
    let reasons: [RecommendationReason]

    var id: Date { start }

    static func segments(for items: [ForecastTimelineItem]) -> [ForecastStatusSegment] {
        guard let first = items.first else { return [] }

        var segments: [ForecastStatusSegment] = []
        var segmentStart = first.date
        var status = first.status
        var reasons = first.reasons

        for index in items.indices.dropFirst() {
            if items[index].status != status {
                segments.append(
                    ForecastStatusSegment(
                        start: segmentStart,
                        end: items[index].date,
                        status: status,
                        reasons: reasons
                    )
                )
                segmentStart = items[index].date
                status = items[index].status
                reasons = items[index].reasons
            } else {
                reasons.append(contentsOf: items[index].reasons.filter { !reasons.contains($0) })
            }
        }

        segments.append(
            ForecastStatusSegment(
                start: segmentStart,
                end: items.dropFirst().last?.date.addingTimeInterval(60 * 60) ?? first.date.addingTimeInterval(60 * 60),
                status: status,
                reasons: reasons
            )
        )

        return segments.smoothedForDisplay()
    }

    var allowsTransientSmoothing: Bool {
        reasons.allSatisfy(\.allowsTransientSmoothing)
    }
}

struct ForecastDayAxisLabel: Identifiable, Equatable {
    let date: Date
    let text: String
    let position: CGFloat

    var id: Date { date }

    static func labels(
        for domain: ClosedRange<Date>,
        width: CGFloat,
        calendar: Calendar = .current,
        locale: Locale = .current,
        labelWidth: CGFloat = 44,
        minimumSpacing: CGFloat = 52
    ) -> [ForecastDayAxisLabel] {
        guard width > 0, domain.upperBound > domain.lowerBound else { return [] }

        let labelInset = min(labelWidth / 2, width / 2)
        var visibleLabels: [ForecastDayAxisLabel] = []

        for span in daySpans(for: domain, calendar: calendar) {
            let startPosition = width * fraction(for: span.start, in: domain)
            let endPosition = width * fraction(for: span.end, in: domain)
            let position = width * fraction(for: span.midpoint, in: domain)

            guard endPosition - startPosition >= labelWidth else {
                continue
            }

            guard labelInset...width - labelInset ~= position else {
                continue
            }

            let label = ForecastDayAxisLabel(
                date: span.start,
                text: weekdayLabel(for: span.start, calendar: calendar, locale: locale),
                position: position
            )

            if visibleLabels.isEmpty || label.position - (visibleLabels.last?.position ?? 0) >= minimumSpacing {
                visibleLabels.append(label)
            }
        }

        return visibleLabels
    }

    private static func daySpans(
        for domain: ClosedRange<Date>,
        calendar: Calendar
    ) -> [DaySpan] {
        guard domain.upperBound > domain.lowerBound else { return [] }

        var spans: [DaySpan] = []
        var start = domain.lowerBound

        while start < domain.upperBound {
            let startOfDay = calendar.startOfDay(for: start)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                break
            }

            let end = min(nextDay, domain.upperBound)
            spans.append(DaySpan(start: start, end: end))
            start = end
        }

        return spans
    }

    private static func fraction(for date: Date, in domain: ClosedRange<Date>) -> CGFloat {
        let duration = domain.upperBound.timeIntervalSince(domain.lowerBound)
        guard duration > 0 else { return 0 }
        return CGFloat(min(max(date.timeIntervalSince(domain.lowerBound) / duration, 0), 1))
    }

    private static func weekdayLabel(for date: Date, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private struct DaySpan {
        let start: Date
        let end: Date

        var midpoint: Date {
            start.addingTimeInterval(end.timeIntervalSince(start) / 2)
        }
    }
}

struct ForecastDayBoundary: Identifiable, Equatable {
    let date: Date
    let position: CGFloat

    var id: Date { date }

    static func boundaries(
        for domain: ClosedRange<Date>,
        width: CGFloat,
        calendar: Calendar = .current
    ) -> [ForecastDayBoundary] {
        guard width > 0, domain.upperBound > domain.lowerBound else { return [] }

        var boundaries: [ForecastDayBoundary] = []
        var boundary = calendar.startOfDay(for: domain.lowerBound)

        if boundary <= domain.lowerBound {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: boundary) else {
                return []
            }
            boundary = nextDay
        }

        while boundary < domain.upperBound {
            boundaries.append(
                ForecastDayBoundary(
                    date: boundary,
                    position: width * fraction(for: boundary, in: domain)
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: boundary) else {
                break
            }
            boundary = nextDay
        }

        return boundaries
    }

    private static func fraction(for date: Date, in domain: ClosedRange<Date>) -> CGFloat {
        let duration = domain.upperBound.timeIntervalSince(domain.lowerBound)
        guard duration > 0 else { return 0 }
        return CGFloat(min(max(date.timeIntervalSince(domain.lowerBound) / duration, 0), 1))
    }
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
        self.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
}

private extension Array where Element == ForecastStatusSegment {
    func smoothedForDisplay() -> [ForecastStatusSegment] {
        guard count >= 3 else { return self }

        var smoothed: [ForecastStatusSegment] = []
        var index = startIndex

        while index < endIndex {
            if index > startIndex,
               index < self.index(before: endIndex),
               self[index].end.timeIntervalSince(self[index].start) <= 60 * 60,
               self[index].allowsTransientSmoothing,
               self[self.index(before: index)].status == self[self.index(after: index)].status {
                let previous = smoothed.removeLast()
                let next = self[self.index(after: index)]
                smoothed.append(
                    ForecastStatusSegment(
                        start: previous.start,
                        end: next.end,
                        status: previous.status,
                        reasons: previous.reasons.merging(next.reasons)
                    )
                )
                index = self.index(index, offsetBy: 2)
            } else {
                smoothed.append(self[index])
                index = self.index(after: index)
            }
        }

        return smoothed
    }
}

extension Array where Element == RecommendationWindow {
    func smoothedForDisplay() -> [RecommendationWindow] {
        guard count >= 3 else { return self }

        var smoothed: [RecommendationWindow] = []
        var index = startIndex

        while index < endIndex {
            if index > startIndex,
               index < self.index(before: endIndex),
               self[index].end.timeIntervalSince(self[index].start) <= 60 * 60,
               self[index].allowsTransientSmoothing,
               self[self.index(before: index)].status == self[self.index(after: index)].status {
                let previous = smoothed.removeLast()
                let next = self[self.index(after: index)]
                smoothed.append(
                    RecommendationWindow(
                        start: previous.start,
                        end: next.end,
                        status: previous.status,
                        reasons: previous.reasons.merging(next.reasons)
                    )
                )
                index = self.index(index, offsetBy: 2)
            } else {
                smoothed.append(self[index])
                index = self.index(after: index)
            }
        }

        return smoothed
    }
}

private extension Array where Element == RecommendationReason {
    func merging(_ other: [RecommendationReason]) -> [RecommendationReason] {
        self + other.filter { !contains($0) }
    }
}
