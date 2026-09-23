import Foundation
import UserNotifications

protocol NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func replaceNotifications(plan: RecommendationPlan, locationName: String, enabled: Bool) async
    func notifyCurrentChange(status: RecommendationStatus, locationName: String) async
}

extension NotificationScheduling {
    func notifyCurrentChange(status: RecommendationStatus, locationName: String) async {}
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
        var rainClosure = first.recommendation.reasons.contains(.activePrecipitation) ||
            first.recommendation.reasons.contains(.recentRain)
        var index = 1

        while index < plan.hourly.count {
            let item = plan.hourly[index]
            if item.recommendation.reasons.contains(.activePrecipitation) ||
                item.recommendation.reasons.contains(.recentRain) {
                rainClosure = true
            }

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
                if item.weather.date > now && !(item.recommendation.status == .open && rainClosure) {
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

struct ImmediateAlertDeduplicator {
    static func shouldSend(
        signature: String,
        now: Date,
        recentSignature: String?,
        recentDate: Date?,
        delivered: [(signature: String, date: Date)]
    ) -> Bool {
        if recentSignature == signature, let recentDate,
           now.timeIntervalSince(recentDate) < 30 * 60 { return false }
        return !delivered.contains { item in
            item.signature == signature && now.timeIntervalSince(item.date) < 30 * 60
        }
    }
}

struct NotificationClient: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "openair.transition."
    private let recentImmediateKey = "openair.lastImmediateAlert"

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
            content.userInfo = ["status": status.rawValue, "location": locationName]

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

    func notifyCurrentChange(status: RecommendationStatus, locationName: String) async {
        let now = Date.now
        let signature = "\(status.rawValue)|\(locationName)"
        let record = UserDefaults.standard.dictionary(forKey: recentImmediateKey)
        let delivered = await center.deliveredNotifications()
        let deliveredSignatures = delivered.compactMap { notification -> (signature: String, date: Date)? in
            guard let status = notification.request.content.userInfo["status"] as? String,
                  let location = notification.request.content.userInfo["location"] as? String else { return nil }
            return ("\(status)|\(location)", notification.date)
        }
        guard ImmediateAlertDeduplicator.shouldSend(
            signature: signature,
            now: now,
            recentSignature: record?["signature"] as? String,
            recentDate: record?["date"] as? Date,
            delivered: deliveredSignatures
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = status == .open ? "Open your windows" : "Keep your windows closed"
        content.body = status == .open
            ? "Outdoor conditions in \(locationName) are favorable."
            : "Outdoor conditions in \(locationName) have changed."
        content.sound = .default
        content.userInfo = ["status": status.rawValue, "location": locationName]
        let request = UNNotificationRequest(
            identifier: "openair.immediate.\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        do {
            try await center.add(request)
            UserDefaults.standard.set(["signature": signature, "date": now], forKey: recentImmediateKey)
        } catch { }
    }
}
