import StoreKit
import SwiftUI

extension View {
    /// Adds app review prompt functionality to the view.
    /// Observes `AppReviewManager.shouldRequestReview` and triggers the review prompt when eligible.
    func withAppReviewPrompt() -> some View {
        modifier(AppReviewRequestViewModifier())
    }
}

private struct AppReviewRequestViewModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @Environment(AppReviewManager.self) private var appReviewManager

    func body(content: Content) -> some View {
        content
            .onChange(of: appReviewManager.shouldRequestReview) { _, shouldRequestReview in
                guard shouldRequestReview else { return }

                requestReview()
                appReviewManager.recordReviewRequestAttempt()
            }
    }
}
