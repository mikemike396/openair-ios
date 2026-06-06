import BackgroundTasks
import SwiftUI

@main
struct OpenAirApp: App {
    static let refreshTaskIdentifier = "com.mikemike396.OpenAir.refresh"

    @Environment(\.scenePhase) private var scenePhase
    @State private var store: AppStore

    init() {
        let store = AppStore()
        _store = State(initialValue: store)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let work = Task {
                await store.refresh()
                refreshTask.setTaskCompleted(success: true)
            }
            refreshTask.expirationHandler = {
                work.cancel()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.start() }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await store.refreshIfNeeded() }
                }
        }
    }
}
