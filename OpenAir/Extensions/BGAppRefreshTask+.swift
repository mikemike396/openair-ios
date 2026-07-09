import BackgroundTasks

extension BGAppRefreshTask: @unchecked @retroactive Sendable {
    // The project defaults declarations to MainActor, but BGTaskScheduler calls this from its own queue.
    // Keep registration nonisolated, then hop to MainActor inside the handler for app state work.
    nonisolated static func registerBackgroundRefresh(store: AppStore) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: String.backgroundRefreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let work = Task { @MainActor in
                let result = await store.refreshForBackground()
                refreshTask.setTaskCompleted(
                    success: result != .failed && !Task.isCancelled
                )
            }
            refreshTask.expirationHandler = {
                work.cancel()
            }
        }
    }
}
