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
        .tint(OpenAirColor.teal)
    }
}

#Preview("Dashboard") {
    let defaults = UserDefaults(suiteName: "RootPreview")!
    defaults.set(true, forKey: "hasCompletedOnboarding")
    return RootView()
        .environment(AppStore(weather: PreviewWeatherClient(), defaults: defaults))
}
