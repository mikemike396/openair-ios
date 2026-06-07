import Foundation

struct DailyWindowTimeline {
    let now: Date
    let start: Date
    let end: Date
    let windows: [RecommendationWindow]

    init(
        windows: [RecommendationWindow],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.now = now

        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            self.start = now
            self.end = now
            self.windows = []
            return
        }

        self.start = dayStart
        self.end = dayEnd

        let visibleWindows = windows.filter {
            now < $0.end && $0.start < dayEnd
        }

        self.windows = visibleWindows.enumerated().compactMap { index, window in
            let displayStart = index == visibleWindows.startIndex
                ? dayStart
                : max(window.start, dayStart)
            let displayEnd = min(window.end, dayEnd)

            guard displayStart < displayEnd else { return nil }

            return RecommendationWindow(
                start: displayStart,
                end: displayEnd,
                status: window.status
            )
        }
    }

    func label(
        for window: RecommendationWindow,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let action = actionLabel(for: window)
        if window.start <= now && now < window.end {
            return "\(action) → \(timeLabel(window.end, calendar: calendar, locale: locale))"
        }
        return "\(action) \(timeLabel(window.start, calendar: calendar, locale: locale)) → \(timeLabel(window.end, calendar: calendar, locale: locale))"
    }

    private func actionLabel(for window: RecommendationWindow) -> String {
        let base: String
        switch window.status {
        case .open: base = "Open"
        case .keepClosed: base = "Keep closed"
        }

        if window.start <= now && now < window.end {
            return "\(base) now"
        }
        return base
    }

    private func timeLabel(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let minute = components.minute else {
            return date.formatted(date: .omitted, time: .shortened)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(minute > 0 ? "jmm" : "j")
        return formatter.string(from: date)
    }
}
