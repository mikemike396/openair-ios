import Foundation
import Observation

@Observable
final class AppReviewManager {
    private static let requiredSignificantEvents = 3
    private static let reviewRequestCooldown: TimeInterval = 60 * 60 * 24 * 90

    private var userPreferences: any UserPreferenceStoring
    private(set) var shouldRequestReview = false

    init(userPreferences: any UserPreferenceStoring = UserPreferenceStore()) {
        self.userPreferences = userPreferences
    }

    func recordSignificantEvent(now: Date = .now) {
        guard !shouldRequestReview, canRequestReview(now: now) else { return }

        userPreferences.reviewSignificantEventCount += 1

        if userPreferences.reviewSignificantEventCount >= Self.requiredSignificantEvents {
            shouldRequestReview = true
        }
    }

    func recordReviewRequestAttempt(now: Date = .now) {
        guard shouldRequestReview else { return }

        shouldRequestReview = false
        userPreferences.reviewSignificantEventCount = 0
        userPreferences.lastReviewRequestAttemptAt = now
    }

    private func canRequestReview(now: Date) -> Bool {
        guard let lastReviewRequestAttemptAt = userPreferences.lastReviewRequestAttemptAt else {
            return true
        }

        return now.timeIntervalSince(lastReviewRequestAttemptAt) >= Self.reviewRequestCooldown
    }
}
