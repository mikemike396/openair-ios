import BackgroundTasks
import OSLog
import UIKit

/// Isolates iOS execution allowances and refresh scheduling from application workflows.
protocol BackgroundRefreshManaging: AnyObject {
    func beginLocationUpdate(expiration: @escaping @MainActor () -> Void)
    func endLocationUpdate()
    func scheduleRefresh()
}

final class BackgroundRefreshClient: BackgroundRefreshManaging {
    private var locationTask: UIBackgroundTaskIdentifier = .invalid

    func beginLocationUpdate(expiration: @escaping @MainActor () -> Void) {
        guard locationTask == .invalid else { return }
        locationTask = UIApplication.shared.beginBackgroundTask(withName: "Update local weather") {
            Task { @MainActor in expiration() }
        }
    }

    func endLocationUpdate() {
        guard locationTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(locationTask)
        locationTask = .invalid
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: String.backgroundRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: .backgroundRefreshInterval)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { Logger().debug("Failed to schedule background refresh: \(error)") }
    }
}
