import SwiftUI

extension View {
    func withAppLifecycleRefresh() -> some View {
        modifier(AppLifecycleRefreshModifier())
    }
}

private struct AppLifecycleRefreshModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @AppCoordinatorEnvironment private var coordinator

    func body(content: Content) -> some View {
        content
            .task {
                if scenePhase == .active { await coordinator.refreshOnActivation() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Inactive includes system permission sheets; stop only on background.
                if newPhase == .background { coordinator.setForeground(false) }
                guard newPhase == .active else { return }
                Task {
                    await coordinator.refreshOnActivation()
                }
            }
    }
}
