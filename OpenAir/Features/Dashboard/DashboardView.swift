import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") {
                    showingSettings = true
                }
                .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(store)
        }
        .refreshable { await store.refreshPreservingLoadedState() }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("Checking outdoor conditions…")
        case .failed(let message, _):
            ContentUnavailableView {
                Label("Weather Unavailable", systemImage: "cloud.fill")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await store.refresh() } }
                    .buttonStyle(.glassProminent)
                Button("Use Demo Weather") { Task { await store.usePreviewWeather() } }
                    .buttonStyle(.glass)
            }
        case .loaded(let snapshot, let plan, let isOffline):
            ScrollView {
                LazyVStack(spacing: 18) {
                    locationHeader(snapshot)
                    if isOffline || snapshot.isStale {
                        staleBanner(snapshot)
                    }
                    RecommendationCard(snapshot: snapshot, plan: plan, unit: store.preferences.temperatureUnit)
                    TodayPlanCard(windows: plan.windows)
                    HourlyList(plan: plan, unit: store.preferences.temperatureUnit)
                    NavigationLink {
                        ScheduleView(snapshot: snapshot, plan: plan, unit: store.preferences.temperatureUnit)
                    } label: {
                        Label("View full schedule", systemImage: "calendar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding()
            }
        }
    }

    private func locationHeader(_ snapshot: WeatherSnapshot) -> some View {
        HStack {
            Label(snapshot.locationName, systemImage: "location")
                .font(.headline)
            Spacer()
            HStack(spacing: 6) {
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("Updated: \(snapshot.fetchedAt, style: .relative) ago")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func staleBanner(_ snapshot: WeatherSnapshot) -> some View {
        Label(
            snapshot.isStale ? "Forecast is stale. Recommendations may be outdated." : "Showing cached weather while offline.",
            systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        )
        .font(.footnote.weight(.medium))
        .foregroundStyle(.openAirAmber)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.openAirAmber.opacity(0.12), in: .rect(cornerRadius: 14))
    }

}

private struct RecommendationCard: View {
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
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(.thinMaterial, in: .capsule)
                        }
                    }
                }
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

private struct TodayPlanCard: View {
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
                            Text(windowLabel(window, index: index, now: timeline.start))
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
            return TimelinePlan(start: now, end: now, windows: [])
        }

        let clipped: [RecommendationWindow] = windows.compactMap { window in
            let start = max(window.start, now)
            let end = min(window.end, dayEnd)
            guard start < end else { return nil }
            return RecommendationWindow(start: start, end: end, status: window.status)
        }
        return TimelinePlan(start: now, end: dayEnd, windows: clipped)
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
        let start: Date
        let end: Date
        let windows: [RecommendationWindow]
    }
}

private struct DayStatusBar: View {
    let windows: [RecommendationWindow]
    let start: Date
    let end: Date

    private let barHeight: CGFloat = 22

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))

                    ForEach(windows) { window in
                        Rectangle()
                            .fill(window.status.color)
                            .frame(
                                width: proxy.size.width * widthFraction(for: window),
                                height: barHeight
                            )
                            .offset(x: proxy.size.width * startFraction(for: window))
                            .overlay(alignment: .leading) {
                                if startFraction(for: window) > 0 {
                                    Rectangle()
                                        .fill(Color(uiColor: .systemBackground))
                                        .frame(width: 1)
                                }
                            }
                    }
                }
                .clipShape(.capsule)
                .overlay {
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
            }
            .frame(height: barHeight)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    ForEach(axisMarks) { mark in
                        Text(mark.label)
                            .frame(width: 56, alignment: mark.alignment)
                            .position(
                                x: min(max(proxy.size.width * fraction(for: mark.date), 28), proxy.size.width - 28),
                                y: 8
                            )
                    }
                }
            }
            .frame(height: 16)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func startFraction(for window: RecommendationWindow) -> Double {
        fraction(for: window.start)
    }

    private func widthFraction(for window: RecommendationWindow) -> Double {
        max(0, fraction(for: window.end) - fraction(for: window.start))
    }

    private func fraction(for date: Date) -> Double {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(start) / duration, 0), 1)
    }

    private var accessibilitySummary: String {
        windows.map {
            "\($0.status.shortTitle) from \($0.start.formatted(date: .omitted, time: .shortened)) to \($0.end.formatted(date: .omitted, time: .shortened))"
        }
        .joined(separator: ". ")
    }

    private var axisMarks: [AxisMark] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: start)
        let boundaries = [6, 12, 18].compactMap {
            calendar.date(bySettingHour: $0, minute: 0, second: 0, of: dayStart)
        }
        var marks = [AxisMark(date: start, label: "Now", alignment: .leading)]
        marks.append(contentsOf: boundaries.filter { start < $0 && $0 < end }.map {
            AxisMark(date: $0, label: $0.formatted(.dateTime.hour()), alignment: .center)
        })
        marks.append(AxisMark(date: end, label: "12 AM", alignment: .trailing))
        return marks
    }

    private struct AxisMark: Identifiable {
        let date: Date
        let label: String
        let alignment: Alignment

        var id: Date { date }
    }
}

private struct HourlyList: View {
    let plan: RecommendationPlan
    let unit: TemperatureUnit

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Next few hours")
                    .font(.title3.bold())
                    .padding(.bottom, 10)
                ForEach(Array(plan.hourly.prefix(8).enumerated()), id: \.element.weather.id) { index, item in
                    NavigationLink {
                        HourDetailView(weather: item.weather, recommendation: item.recommendation, unit: unit)
                    } label: {
                        HStack {
                            Text(index == 0 ? "Now" : item.weather.date.formatted(.dateTime.hour()))
                                .frame(width: 62, alignment: .leading)
                            StatusPill(status: item.recommendation.status)
                            Spacer()
                            Text(
                                "\(unit.display(item.weather.temperatureFahrenheit))° / DP \(unit.display(item.weather.dewPointFahrenheit))°"
                            )
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .lineLimit(1)
                                .accessibilityLabel(
                                    "Temperature \(unit.display(item.weather.temperatureFahrenheit))\(unit.symbol), dew point \(unit.display(item.weather.dewPointFahrenheit))\(unit.symbol)"
                                )
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if index < min(plan.hourly.count, 8) - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

#Preview("Loading") {
    DashboardPreview(state: .loading)
}

#Preview("Open") {
    DashboardPreview.loaded(status: .open)
}

#Preview("Closed") {
    DashboardPreview.loaded(status: .keepClosed)
}

#Preview("Stale / Offline") {
    DashboardPreview.loaded(status: .open, isOffline: true, isStale: true)
}

#Preview("Error") {
    DashboardPreview(state: .failed(message: "Weather service is unavailable.", cached: nil))
}

@MainActor
private struct DashboardPreview: View {
    @State private var store: AppStore

    init(state: DashboardLoadState) {
        let store = Self.makeStore()
        store.loadState = state
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            DashboardView()
        }
        .environment(store)
    }

    static func loaded(
        status: RecommendationStatus,
        isOffline: Bool = false,
        isStale: Bool = false
    ) -> DashboardPreview {
        let base = WeatherSnapshot.preview
        let current: HourlyWeather
        switch status {
        case .open:
            current = base.current
        case .keepClosed:
            current = replacing(base.current, temperature: 80, dewPoint: 64)
        }
        let snapshot = WeatherSnapshot(
            locationName: base.locationName,
            coordinate: base.coordinate,
            fetchedAt: isStale ? .now.addingTimeInterval(-60 * 60 * 4) : .now,
            current: current,
            hourly: [current] + Array(base.hourly.dropFirst())
        )
        let plan = RecommendationEngine().plan(snapshot: snapshot, preferences: .default)
        return DashboardPreview(state: .loaded(snapshot: snapshot, plan: plan, isOffline: isOffline))
    }

    private static func replacing(
        _ weather: HourlyWeather,
        temperature: Double,
        dewPoint: Double
    ) -> HourlyWeather {
        HourlyWeather(
            date: weather.date,
            temperatureFahrenheit: temperature,
            dewPointFahrenheit: dewPoint,
            precipitationChance: weather.precipitationChance,
            isPrecipitating: weather.isPrecipitating,
            isThunderstorm: weather.isThunderstorm,
            windMPH: weather.windMPH,
            gustMPH: weather.gustMPH,
            symbolName: weather.symbolName
        )
    }

    private static func makeStore() -> AppStore {
        let defaults = UserDefaults(suiteName: "DashboardPreview.\(UUID().uuidString)")!
        defaults.set(true, forKey: "hasCompletedOnboarding")
        return AppStore(weather: PreviewWeatherClient(), defaults: defaults)
    }
}
