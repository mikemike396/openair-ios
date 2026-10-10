import BackgroundTasks
import SwiftUI

final class DependencyContainer {
    let userPreferenceStore: UserPreferenceStoring
    let appReviewManager: AppReviewManager
    let weatherStore: WeatherStore
    let locationStore: LocationStore
    let notificationStore: NotificationStore
    let appCoordinator: AppCoordinator
    let tipTransactionObserver: TipTransactionObserver

    init() {
        let userPreferenceStore = UserPreferenceStore()
        let appReviewManager = AppReviewManager(userPreferences: userPreferenceStore)
        let location = LocationClient()
        let locationStore = LocationStore(provider: location, places: MapKitPlaceSearchClient(), preferences: userPreferenceStore)
        let weatherStore = WeatherStore(
            requests: WeatherRequestCoordinator(weather: WeatherKitClient(), location: location, preferences: userPreferenceStore),
            evaluator: RecommendationEngine(), cache: WeatherCache(),
            widgets: WidgetSnapshotPublisher(), preferences: userPreferenceStore
        )
        let notificationStore = NotificationStore(scheduler: NotificationClient(), preferences: userPreferenceStore)
        let appCoordinator = AppCoordinator(
            weather: weatherStore, location: locationStore, notifications: notificationStore,
            preferences: userPreferenceStore, reviews: appReviewManager, background: BackgroundRefreshClient()
        )

        self.userPreferenceStore = userPreferenceStore
        self.appReviewManager = appReviewManager
        self.weatherStore = weatherStore
        self.locationStore = locationStore
        self.notificationStore = notificationStore
        self.appCoordinator = appCoordinator
        self.tipTransactionObserver = TipTransactionObserver()
        
        setup()
    }
    
    private func setup() {
        registerBackgroundRefreshTask()
    }

    private func registerBackgroundRefreshTask() {
        BGAppRefreshTask.registerBackgroundRefresh(coordinator: appCoordinator)
    }
}

extension View {
    func withDependencies(
        _ dependencies: DependencyContainer
    ) -> some View {
        self
            .environment(\.userPreferenceStore, dependencies.userPreferenceStore)
            .environment(dependencies.weatherStore)
            .environment(dependencies.locationStore)
            .environment(dependencies.notificationStore)
            .environment(\.appCoordinator, dependencies.appCoordinator)
            .environment(dependencies.appReviewManager)
    }
}
