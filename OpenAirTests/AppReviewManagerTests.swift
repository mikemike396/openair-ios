import Foundation
import Testing
@testable import OpenAir

@Suite
@MainActor
struct AppReviewManagerTests {
    @Test
    func waitsUntilThirdSignificantEvent() {
        let userPreferences = ReviewUserPreferenceStore()
        let manager = AppReviewManager(userPreferences: userPreferences)

        manager.recordSignificantEvent()
        manager.recordSignificantEvent()

        #expect(!manager.shouldRequestReview)

        manager.recordSignificantEvent()

        #expect(manager.shouldRequestReview)
        #expect(userPreferences.reviewSignificantEventCount == 3)
    }

    @Test
    func requestAttemptClearsPendingRequestAndStartsCooldown() throws {
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 17)))
        let userPreferences = ReviewUserPreferenceStore()
        let manager = AppReviewManager(userPreferences: userPreferences)

        manager.recordSignificantEvent(now: now)
        manager.recordSignificantEvent(now: now)
        manager.recordSignificantEvent(now: now)
        manager.recordReviewRequestAttempt(now: now)

        #expect(!manager.shouldRequestReview)
        #expect(userPreferences.reviewSignificantEventCount == 0)
        #expect(userPreferences.lastReviewRequestAttemptAt == now)
    }

    @Test
    func cooldownSuppressesNewRequestAttempts() throws {
        let requestedAt = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 17)))
        let beforeCooldownEnds = requestedAt.addingTimeInterval(60 * 60 * 24 * 89)
        let userPreferences = ReviewUserPreferenceStore()
        userPreferences.lastReviewRequestAttemptAt = requestedAt
        let manager = AppReviewManager(userPreferences: userPreferences)

        manager.recordSignificantEvent(now: beforeCooldownEnds)
        manager.recordSignificantEvent(now: beforeCooldownEnds)
        manager.recordSignificantEvent(now: beforeCooldownEnds)

        #expect(!manager.shouldRequestReview)
        #expect(userPreferences.reviewSignificantEventCount == 0)
    }

    @Test
    func eventsAfterCooldownCanRequestReviewAgain() throws {
        let requestedAt = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 17)))
        let afterCooldownEnds = requestedAt.addingTimeInterval(60 * 60 * 24 * 90)
        let userPreferences = ReviewUserPreferenceStore()
        userPreferences.lastReviewRequestAttemptAt = requestedAt
        let manager = AppReviewManager(userPreferences: userPreferences)

        manager.recordSignificantEvent(now: afterCooldownEnds)
        manager.recordSignificantEvent(now: afterCooldownEnds)
        manager.recordSignificantEvent(now: afterCooldownEnds)

        #expect(manager.shouldRequestReview)
        #expect(userPreferences.reviewSignificantEventCount == 3)
    }
}

@MainActor
private final class ReviewUserPreferenceStore: UserPreferenceStoring {
    var hasCompletedOnboarding = false
    var savedPlace: SavedPlace?
    var lastKnownCurrentLocation: SavedPlace?
    var preferences = ComfortPreferences.default(for: Locale(identifier: "en_US"))
    var reviewSignificantEventCount = 0
    var lastReviewRequestAttemptAt: Date?
}
