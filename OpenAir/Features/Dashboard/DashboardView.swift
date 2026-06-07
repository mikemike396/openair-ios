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
                        ForecastView(plan: plan, unit: store.preferences.temperatureUnit)
                    } label: {
                        Label("View forecast", systemImage: "chart.xyaxis.line")
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
