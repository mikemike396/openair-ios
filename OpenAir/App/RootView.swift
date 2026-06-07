import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .tint(.accentColor)
    }
}

#Preview("Dashboard") {
    let defaults = UserDefaults(suiteName: "RootPreview")!
    let userPreferences = UserPreferenceStore(userDefaults: defaults)
    userPreferences.hasCompletedOnboarding = true
    return RootView()
        .environment(
            AppStore(weather: PreviewWeatherClient(), userPreferences: userPreferences)
        )
}
