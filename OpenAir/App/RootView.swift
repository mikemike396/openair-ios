import SwiftUI

struct RootView: View {
    @Environment(\.userPreferenceStore) private var preferences

    var body: some View {
        NavigationStack {
            if preferences.hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .withAppReviewPrompt()
        .tint(.accentColor)
    }
}
