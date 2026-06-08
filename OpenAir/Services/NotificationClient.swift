import Foundation
import UserNotifications

@MainActor
protocol NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async
}

struct NotificationTransition: Equatable, Sendable {
    let date: Date
    let status: RecommendationStatus
}

struct NotificationTransitionPlanner: Sendable {
    func transitions(in plan: RecommendationPlan, after now: Date = .now) -> [NotificationTransition] {
        guard let first = plan.hourly.first else { return [] }

        var transitions: [NotificationTransition] = []
        var effectiveStatus = first.recommendation.status
        var index = 1

        while index < plan.hourly.count {
            let item = plan.hourly[index]

            if shouldSuppressOneHourChange(
                at: index,
                in: plan.hourly,
                surroundingStatus: effectiveStatus
            ) {
                index += 2
                continue
            }

            if item.recommendation.status != effectiveStatus {
                effectiveStatus = item.recommendation.status
                if item.weather.date > now {
                    transitions.append(
                        NotificationTransition(
                            date: item.weather.date,
                            status: item.recommendation.status
                        )
                    )
                }
            }

            index += 1
        }

        return transitions
    }

    private func shouldSuppressOneHourChange(
        at index: Int,
        in hourly: [(weather: HourlyWeather, recommendation: Recommendation)],
        surroundingStatus: RecommendationStatus
    ) -> Bool {
        guard index + 1 < hourly.count else { return false }

        let item = hourly[index]
        let next = hourly[index + 1]

        return item.recommendation.status != surroundingStatus &&
            next.recommendation.status == surroundingStatus &&
            next.weather.date.timeIntervalSince(item.weather.date) <= 60 * 60 &&
            item.recommendation.reasons.allSatisfy(\.allowsTransientSmoothing)
    }
}

@MainActor
struct NotificationClient: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "openair.transition."

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        )
        guard enabled else { return }

        let transitions = NotificationTransitionPlanner().transitions(in: plan)

        for transition in transitions.prefix(2) {
            let date = transition.date
            let status = transition.status
            let content = UNMutableNotificationContent()
            let favorable = status == .open
            content.title = favorable ? "Open your windows" : "Keep your windows closed"
            content.body = favorable
                ? "Outdoor conditions in \(locationName) are favorable."
                : "Outdoor conditions in \(locationName) are expected to worsen."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "\(prefix)\(Int(date.timeIntervalSince1970))",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: date
                    ),
                    repeats: false
                )
            )
            try? await center.add(request)
        }
    }
}
