import Foundation

protocol RecommendationStatusInterval {
    var start: Date { get }
    var end: Date { get }
    var status: RecommendationStatus { get }
    var reasons: [RecommendationReason] { get }

    init(
        start: Date,
        end: Date,
        status: RecommendationStatus,
        reasons: [RecommendationReason]
    )
}

extension RecommendationWindow: RecommendationStatusInterval {}
extension ForecastStatusSegment: RecommendationStatusInterval {}

/// Utilities for presenting recommendation intervals without brief, low-risk
/// status fluctuations that would create noisy guidance.
extension Array where Element: RecommendationStatusInterval {
    /// Merges a status interval of one hour or less into matching intervals on
    /// either side when every reason permits transient smoothing.
    ///
    /// Safety-related changes, including precipitation, thunderstorms, extreme
    /// conditions, and dangerous gusts, are preserved regardless of duration.
    func mergingTransientStatusChanges() -> [Element] {
        guard count >= 3 else { return self }

        var merged: [Element] = []
        var index = startIndex

        while index < endIndex {
            if index > startIndex,
               index < self.index(before: endIndex),
               self[index].end.timeIntervalSince(self[index].start) <= 60 * 60,
               self[index].reasons.allSatisfy(\.allowsTransientSmoothing),
               self[self.index(before: index)].status == self[self.index(after: index)].status {
                let previous = merged.removeLast()
                let next = self[self.index(after: index)]
                merged.append(
                    Element(
                        start: previous.start,
                        end: next.end,
                        status: previous.status,
                        reasons: previous.reasons.merging(next.reasons)
                    )
                )
                index = self.index(index, offsetBy: 2)
            } else {
                merged.append(self[index])
                index = self.index(after: index)
            }
        }

        return merged
    }
}
