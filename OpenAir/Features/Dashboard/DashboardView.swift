import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @State private var showingSettings = false

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text(navigationTitle)
                            .lineLimit(1)
                            .layoutPriority(1)
                        Image(systemName: store.savedPlace == nil ? "location" : "mappin")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .refreshable {
                await store.refresh(keepsLoadedState: true)
            }
            .appBackground()
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
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
        case .loaded(let snapshot, let plan):
            ScrollView {
                LazyVStack(spacing: 18) {
                    if store.shouldShowStaleBanner(for: snapshot) {
                        staleBanner
                    }
                    RecommendationCard(
                        snapshot: snapshot,
                        plan: plan,
                        unit: store.preferences.temperatureUnit,
                        temperatureSource: store.preferences.temperatureEvaluationSource,
                        isRefreshing: store.refreshState == .refreshing
                    )
                    NavigationLink {
                        ForecastView(plan: plan, preferences: store.preferences)
                    } label: {
                        TodayPlanCard(windows: plan.windows)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the 48-hour forecast")
                    HourlyList(plan: plan, preferences: store.preferences)
                    NavigationLink {
                        ForecastView(plan: plan, preferences: store.preferences)
                    } label: {
                        Label("View forecast", systemImage: "chart.xyaxis.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    WeatherAttributionView()
                }
                .padding()
            }
        }
    }

    private var navigationTitle: String {
        if case .loaded(let snapshot, _) = store.loadState {
            snapshot.locationName
        } else {
            ""
        }
    }

    private var staleBanner: some View {
        Label(
            "Forecast is stale. Recommendations may be outdated.",
            systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        )
        .font(.footnote.weight(.medium))
        .foregroundStyle(.openAirAmber)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.openAirAmber.opacity(0.12), in: .rect(cornerRadius: 14))
    }
}
