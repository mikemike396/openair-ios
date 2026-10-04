import SwiftUI

struct DashboardView: View {
    @Environment(WeatherStore.self) private var weather
    @Environment(LocationStore.self) private var location
    @Environment(\.userPreferenceStore) private var preferences
    @AppCoordinatorEnvironment private var coordinator
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
                        Image(systemName: location.savedPlace == nil ? "location" : "mappin")
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
                await coordinator.refresh(keepsLoadedState: true)
            }
            .appBackground()
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch weather.loadState {
        case .idle, .loading:
            ProgressView("Checking outdoor conditions…")
        case .failed(let message, _):
            ContentUnavailableView {
                Label("Weather Unavailable", systemImage: "cloud.fill")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await coordinator.refresh() } }
                    .buttonStyle(.glassProminent)
                Button("Use Demo Weather") { Task { await weather.usePreviewWeather() } }
                    .buttonStyle(.glass)
            }
        case .loaded(let snapshot, let plan):
            ScrollView {
                LazyVStack(spacing: 18) {
                    if weather.shouldShowStaleBanner(for: snapshot) {
                        staleBanner
                    }
                    RecommendationCard(
                        snapshot: snapshot,
                        plan: plan,
                        unit: preferences.preferences.temperatureUnit,
                        temperatureSource: preferences.preferences.temperatureEvaluationSource,
                        isRefreshing: weather.refreshState == .refreshing
                    )
                    if location.showsBackgroundFollowTip {
                        backgroundFollowTip
                    }
                    NavigationLink {
                        ForecastView(
                            plan: plan,
                            preferences: preferences.preferences,
                            forecastRange: Binding(
                                get: { preferences.forecastRange },
                                set: { preferences.forecastRange = $0 }
                            )
                        )
                    } label: {
                        TodayPlanCard(windows: plan.windows)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the 10-day forecast")
                    HourlyList(
                        plan: plan,
                        preferences: preferences.preferences,
                        forecastRange: Binding(
                            get: { preferences.forecastRange },
                            set: { preferences.forecastRange = $0 }
                        )
                    )
                    NavigationLink {
                        ForecastView(
                            plan: plan,
                            preferences: preferences.preferences,
                            forecastRange: Binding(
                                get: { preferences.forecastRange },
                                set: { preferences.forecastRange = $0 }
                            )
                        )
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
        if case .loaded(let snapshot, _) = weather.loadState {
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

    private var backgroundFollowTip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Traveling?", systemImage: "location.fill")
                    .font(.headline)
                Spacer()
                Button {
                    location.dismissBackgroundFollowTip()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Dismiss background following tip")
            }
            Text("Let OpenAir follow your weather when the app is closed.")
                .font(.subheadline)
            Button("Set up background following") {
                location.dismissBackgroundFollowTip()
                showingSettings = true
            }
            .buttonStyle(.glass)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.openAirTeal.opacity(0.12), in: .rect(cornerRadius: 18))
        .accessibilityIdentifier("backgroundFollowTip")
    }
}
