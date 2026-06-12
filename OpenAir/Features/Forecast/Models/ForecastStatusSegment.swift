import Foundation

struct ForecastStatusSegment: Identifiable, Equatable {
    let start: Date
    let end: Date
    let status: RecommendationStatus
    let reasons: [RecommendationReason]

    var id: Date { start }

    static func segments(for items: [ForecastTimelineItem]) -> [ForecastStatusSegment] {
        guard let first = items.first else { return [] }

        var segments: [ForecastStatusSegment] = []
        var segmentStart = first.date
        var status = first.status
        var reasons = first.reasons

        for item in items.dropFirst() {
            if item.status != status {
                segments.append(
                    ForecastStatusSegment(
                        start: segmentStart,
                        end: item.date,
                        status: status,
                        reasons: reasons
                    )
                )
                segmentStart = item.date
                status = item.status
                reasons = item.reasons
            } else {
                reasons.append(contentsOf: item.reasons.filter { !reasons.contains($0) })
            }
        }

        segments.append(
            ForecastStatusSegment(
                start: segmentStart,
                end: items.dropFirst().last?.date.addingTimeInterval(60 * 60)
                    ?? first.date.addingTimeInterval(60 * 60),
                status: status,
                reasons: reasons
            )
        )

        return segments.mergingTransientStatusChanges()
    }
}

extension ForecastStatusSegment: RecommendationStatusInterval {}
