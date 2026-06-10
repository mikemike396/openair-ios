import BackgroundTasks
import SwiftUI

@main
struct OpenAirApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AppStore()

    init() {
        BGAppRefreshTask.registerBackgroundRefresh(store: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
                    await store.start()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await store.refreshIfNeeded()
                    }
                }
        }
    }
}

extension BGAppRefreshTask: @unchecked @retroactive Sendable {
    static func registerBackgroundRefresh(store: AppStore) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: String.backgroundRefreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let work = Task { @MainActor in
                let result = await store.refreshPreservingLoadedState()
                refreshTask.setTaskCompleted(
                    success: result == .succeeded && !Task.isCancelled
                )
            }
            refreshTask.expirationHandler = {
                work.cancel()
            }
        }
    }
}
