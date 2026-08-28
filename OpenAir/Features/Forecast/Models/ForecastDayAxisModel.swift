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

        let duration = domain.upperBound.timeIntervalSince(domain.lowerBound)
        if duration <= 48 * 60 * 60 {
            return hourlyLabels(
                for: domain,
                width: width,
                calendar: calendar,
                locale: locale,
                labelWidth: labelWidth,
                minimumSpacing: minimumSpacing
            )
        }

        return dailyLabels(
            for: domain,
            width: width,
            calendar: calendar,
            locale: locale,
            labelWidth: labelWidth,
            minimumSpacing: minimumSpacing,
            dayInterval: duration <= 5 * 24 * 60 * 60 ? 1 : 2
        )
    }

    private static func hourlyLabels(
        for domain: ClosedRange<Date>,
        width: CGFloat,
        calendar: Calendar,
        locale: Locale,
        labelWidth: CGFloat,
        minimumSpacing: CGFloat
    ) -> [ForecastDayAxisLabel] {
        let duration = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let intervalHours = duration <= 24 * 60 * 60 ? 4 : 6
        let labelInset = min(labelWidth / 2, width / 2)
        let effectiveMinimumSpacing = min(minimumSpacing, 38)
        var labels: [ForecastDayAxisLabel] = []
        var marker = calendar.dateInterval(of: .hour, for: domain.lowerBound)?.start ?? domain.lowerBound

        while marker < domain.lowerBound || calendar.component(.hour, from: marker) % intervalHours != 0 {
            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: marker) else { return labels }
            marker = nextHour
        }

        while marker < domain.upperBound {
            let position = width * fraction(for: marker, in: domain)
            if labelInset...width - labelInset ~= position,
               labels.isEmpty || position - (labels.last?.position ?? 0) >= effectiveMinimumSpacing
            {
                labels.append(
                    ForecastDayAxisLabel(
                        date: marker,
                        text: hourlyLabel(for: marker, calendar: calendar, locale: locale),
                        position: position
                    )
                )
            }

            guard let nextMarker = calendar.date(byAdding: .hour, value: intervalHours, to: marker) else {
                return labels
            }
            marker = nextMarker
        }

        return labels
    }

    private static func dailyLabels(
        for domain: ClosedRange<Date>,
        width: CGFloat,
        calendar: Calendar,
        locale: Locale,
        labelWidth: CGFloat,
        minimumSpacing: CGFloat,
        dayInterval: Int
    ) -> [ForecastDayAxisLabel] {
        let labelInset = min(labelWidth / 2, width / 2)
        var labels: [ForecastDayAxisLabel] = []
        var day = calendar.startOfDay(for: domain.lowerBound)

        guard let firstDay = calendar.date(byAdding: .day, value: 1, to: day) else { return [] }
        day = firstDay

        while day < domain.upperBound {
            let position = width * fraction(for: midpoint(of: day, calendar: calendar), in: domain)
            if labelInset...width - labelInset ~= position,
               labels.isEmpty || position - (labels.last?.position ?? 0) >= minimumSpacing
            {
                labels.append(
                    ForecastDayAxisLabel(
                        date: day,
                        text: dailyLabel(for: day, calendar: calendar, locale: locale),
                        position: position
                    )
                )
            }

            guard let nextDay = calendar.date(byAdding: .day, value: dayInterval, to: day) else {
                return labels
            }
            day = nextDay
        }

        return labels
    }

    private static func midpoint(of day: Date, calendar: Calendar) -> Date {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return day }
        return day.addingTimeInterval(nextDay.timeIntervalSince(day) / 2)
    }

    private static func fraction(for date: Date, in domain: ClosedRange<Date>) -> CGFloat {
        let duration = domain.upperBound.timeIntervalSince(domain.lowerBound)
        guard duration > 0 else { return 0 }
        return CGFloat(min(max(date.timeIntervalSince(domain.lowerBound) / duration, 0), 1))
    }

    private static func hourlyLabel(
        for date: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        date.formatted(
            Date.FormatStyle(
                locale: locale,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
            .hour(.defaultDigits(amPM: .abbreviated))
        )
    }

    private static func dailyLabel(
        for date: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let weekday = date.formatted(
            Date.FormatStyle(
                locale: locale,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
            .weekday(.abbreviated)
        )
        let day = date.formatted(
            Date.FormatStyle(
                locale: locale,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
            .day()
        )
        return "\(weekday) \(day)"
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
