import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        NavigationStack {
            if appStore.hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .withAppReviewPrompt()
        .tint(.accentColor)
    }
}
