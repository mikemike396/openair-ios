import SwiftUI
import UIKit

@main
struct OpenAirApp: App {
    @UIApplicationDelegateAdaptor(OpenAirAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .withAppLifecycleRefresh()
                .withDependencies(appDelegate.dependencies)
        }
    }
}

final class OpenAirAppDelegate: NSObject, UIApplicationDelegate {
    let dependencies = DependencyContainer()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Significant-change relaunches may have no active SwiftUI scene.
        dependencies.appStore.synchronizeLocationMonitoring()
        return true
    }
}
