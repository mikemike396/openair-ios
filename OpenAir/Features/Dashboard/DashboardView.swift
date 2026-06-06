import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .navigationTitle("OpenAir")
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
        .refreshable { await store.refresh() }
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
                    NavigationLink {
                        ScheduleView(snapshot: snapshot, plan: plan, unit: store.preferences.temperatureUnit)
                    } label: {
                        Label("View full schedule", systemImage: "calendar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    TodayPlanCard(windows: plan.windows)
                    HourlyList(plan: plan, unit: store.preferences.temperatureUnit)
                    attribution
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
            Text("Updated \(snapshot.fetchedAt, style: .relative) ago")
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
        .foregroundStyle(OpenAirColor.amber)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OpenAirColor.amber.opacity(0.12), in: .rect(cornerRadius: 14))
    }

    private var attribution: some View {
        VStack(spacing: 4) {
            Text("Weather data provided by Apple Weather")
            Text("Alerts are best-effort and may be delayed by iOS.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.vertical, 8)
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
        case .good: "Mostly favorable outdoor conditions."
        case .marginal: "Conditions are borderline."
        case .keepClosed: "Outdoor conditions are unfavorable."
        }
    }
}

private struct TodayPlanCard: View {
    let windows: [RecommendationWindow]

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today’s window plan")
                    .font(.title3.bold())
                ForEach(windows.prefix(5)) { window in
                    HStack {
                        Circle()
                            .fill(window.status.color)
                            .frame(width: 10, height: 10)
                        Text(window.status.shortTitle)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(window.start.formatted(date: .omitted, time: .shortened))–\(window.end.formatted(date: .omitted, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
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
                ForEach(plan.hourly.prefix(8), id: \.weather.id) { item in
                    NavigationLink {
                        HourDetailView(weather: item.weather, recommendation: item.recommendation, unit: unit)
                    } label: {
                        HStack {
                            Text(item.weather.date, format: .dateTime.hour())
                                .frame(width: 62, alignment: .leading)
                            StatusPill(status: item.recommendation.status)
                            Spacer()
                            Text("\(unit.display(item.weather.temperatureFahrenheit))\(unit.symbol)")
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if item.weather.id != plan.hourly.prefix(8).last?.weather.id {
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

#Preview("Marginal") {
    DashboardPreview.loaded(status: .marginal)
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
        case .good:
            current = replacing(base.current, temperature: 80, dewPoint: 55)
        case .marginal:
            current = replacing(base.current, temperature: 80, dewPoint: 64)
        case .keepClosed:
            current = replacing(base.current, temperature: 86, dewPoint: 69)
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
