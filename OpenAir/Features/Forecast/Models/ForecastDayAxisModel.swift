import Foundation

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

            guard endPosition - startPosition >= labelWidth else { continue }
            guard labelInset...width - labelInset ~= position else { continue }

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
