import BackgroundTasks
import SwiftUI

@MainActor
final class DependencyContainer {
    let userPreferenceStore: UserPreferenceStoring
    let appReviewManager: AppReviewManager
    let appStore: AppStore

    init() {
        let userPreferenceStore = UserPreferenceStore()
        let appReviewManager = AppReviewManager(userPreferences: userPreferenceStore)
        let appStore = AppStore(
            widgetPublisher: WidgetSnapshotPublisher(),
            userPreferences: userPreferenceStore,
            appReviewManager: appReviewManager
        )

        self.userPreferenceStore = userPreferenceStore
        self.appReviewManager = appReviewManager
        self.appStore = appStore
        
        setup()
    }
    
    private func setup() {
        registerBackgroundRefreshTask()
    }

    private func registerBackgroundRefreshTask() {
        BGAppRefreshTask.registerBackgroundRefresh(store: appStore)
    }
}

extension View {
    func withDependencies(
        _ dependencies: DependencyContainer
    ) -> some View {
        self
            .environment(\.userPreferenceStore, dependencies.userPreferenceStore)
            .environment(dependencies.appStore)
            .environment(dependencies.appReviewManager)
    }
}
