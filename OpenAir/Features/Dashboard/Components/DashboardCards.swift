import SwiftUI

struct RecommendationCard: View {
    let snapshot: WeatherSnapshot
    let plan: RecommendationPlan
    let unit: TemperatureUnit
    let isRefreshing: Bool
    private let cardHorizontalPadding: CGFloat = 20

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
                    Label(RecommendationChangeText.text(for: nextChange), systemImage: "clock")
                        .font(.subheadline.weight(.medium))
                }

                Divider()
                HStack {
                    Label("\(unit.display(snapshot.current.temperatureFahrenheit))\(unit.symbol)", systemImage: snapshot.current.symbolName)
                    Spacer()
                    Label {
                        Text("\(unit.display(snapshot.current.dewPointFahrenheit))\(unit.symbol)")
                    } icon: {
                        Image(systemName: "drop")
                            .foregroundStyle(Color(.openAirBlue))
                    }
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
                    .padding(.horizontal, cardHorizontalPadding)
                }
                .padding(.horizontal, -cardHorizontalPadding)

                HStack(spacing: 4) {
                    Text("Updated:")
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Updating weather")
                    } else {
                        Text("\(snapshot.fetchedAt, style: .relative) ago")
                    }
                }
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

enum RecommendationChangeText {
    static func text(
        for date: Date,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        let timeStyle = Date.FormatStyle(
            date: .omitted,
            time: .shortened,
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        let weekdayStyle = Date.FormatStyle(
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        .weekday(.wide)

        return "Expected to change around \(date.formatted(timeStyle)) \(date.formatted(weekdayStyle))"
    }
}

struct TodayPlanCard: View {
    let windows: [RecommendationWindow]

    var body: some View {
        let timeline = DailyWindowTimeline(windows: windows)

        WeatherCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rest of today")
                    .font(.title3.bold())

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(timeline.windows) { window in
                        Label {
                            Text(timeline.label(for: window))
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
}
