import SwiftUI

extension EnvironmentValues {
    @Entry var userPreferenceStore: UserPreferenceStoring = DefaultNoOpUserPreferenceStore()
}

// Default no-op implementation
final class DefaultNoOpUserPreferenceStore: UserPreferenceStoring {
    var hasCompletedOnboarding: Bool = false
    var savedPlace: SavedPlace? = nil
    var lastKnownCurrentLocation: SavedPlace? = nil
    var preferences: ComfortPreferences = .init()
    var reviewSignificantEventCount: Int = 0
    var lastReviewRequestAttemptAt: Date? = nil
}
