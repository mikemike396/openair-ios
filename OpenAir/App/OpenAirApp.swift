import SwiftUI

@main
struct OpenAirApp: App {
    @State private var dependencyContainer = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .withAppLifecycleRefresh()
                .withDependencies(dependencyContainer)
        }
    }
}
