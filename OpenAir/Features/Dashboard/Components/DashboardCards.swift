import SwiftUI

struct RecommendationCard: View {
    let snapshot: WeatherSnapshot
    let plan: RecommendationPlan
    let unit: TemperatureUnit

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(plan.current.status.title.uppercased())
                            .font(.title.bold())
                            .foregroundStyle(plan.current.status.color)
                        Text(summary)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: plan.current.status.symbol)
                        .font(.system(size: 52))
                        .foregroundStyle(plan.current.status.color)
                }

                if let nextChange = plan.nextChange {
                    Label("Expected to change around \(nextChange.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                        .font(.subheadline.weight(.medium))
                }

                Divider()
                HStack {
                    Label("\(unit.display(snapshot.current.temperatureFahrenheit))\(unit.symbol)", systemImage: snapshot.current.symbolName)
                    Spacer()
                    Label("DP \(unit.display(snapshot.current.dewPointFahrenheit))\(unit.symbol)", systemImage: "drop")
                    Spacer()
                    Label("\(Int(snapshot.current.windMPH.rounded())) mph", systemImage: "wind")
                }
                .font(.subheadline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(plan.current.reasons, id: \.self) { reason in
                            Label(reason.label, systemImage: reason.symbol)
                                .font(.caption.weight(.medium))
                                .chip()
                        }
                    }
                }

                Text("Updated: \(snapshot.fetchedAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        switch plan.current.status {
        case .open: "Outdoor conditions are comfortable."
        case .keepClosed: "Outdoor conditions are unfavorable."
        }
    }
}

struct TodayPlanCard: View {
    let windows: [RecommendationWindow]

    var body: some View {
        let timeline = timelinePlan

        WeatherCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today’s window plan")
                    .font(.title3.bold())

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(timeline.windows.enumerated()), id: \.element.id) { index, window in
                        Label {
                            Text(windowLabel(window, index: index, now: timeline.now))
                        } icon: {
                            Circle()
                                .fill(window.status.color)
                                .frame(width: 10, height: 10)
                        }
                        .font(.subheadline)
                    }
                }

                DayStatusBar(windows: timeline.windows, start: timeline.start, end: timeline.end)
            }
        }
    }

    private var timelinePlan: TimelinePlan {
        let now = Date()
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return TimelinePlan(now: now, start: now, end: now, windows: [])
        }

        let visibleWindows = windows.filter { now < $0.end && $0.start < dayEnd }
        let clipped: [RecommendationWindow] = visibleWindows.enumerated().compactMap { index, window in
            let start = max(window.start, now)
            let displayStart = index == visibleWindows.startIndex ? dayStart : max(window.start, dayStart)
            let end = min(window.end, dayEnd)
            guard displayStart < end, start < end else { return nil }
            return RecommendationWindow(start: displayStart, end: end, status: window.status)
        }
        return TimelinePlan(now: now, start: dayStart, end: dayEnd, windows: clipped)
    }

    private func windowLabel(_ window: RecommendationWindow, index: Int, now: Date) -> String {
        let isCurrent = window.start <= now && now < window.end
        let action: String
        switch (window.status, isCurrent, index) {
        case (.open, true, _): action = "Open now"
        case (.open, false, 0): action = "Open"
        case (.open, false, _): action = "Open again"
        case (.keepClosed, true, _): action = "Keep closed now"
        case (.keepClosed, false, _): action = "Keep closed"
        }

        if isCurrent {
            return "\(action) → \(timeLabel(window.end))"
        }
        return "\(action) \(timeLabel(window.start)) → \(timeLabel(window.end))"
    }

    private func timeLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if date == calendar.startOfDay(for: date) {
            return "12 AM"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private struct TimelinePlan {
        let now: Date
        let start: Date
        let end: Date
        let windows: [RecommendationWindow]
    }
}
