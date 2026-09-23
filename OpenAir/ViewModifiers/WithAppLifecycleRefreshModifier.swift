import SwiftUI

extension View {
    func withAppLifecycleRefresh() -> some View {
        modifier(AppLifecycleRefreshModifier())
    }
}

private struct AppLifecycleRefreshModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppStore.self) private var store

    func body(content: Content) -> some View {
        content
            .task {
                if scenePhase == .active { await store.start() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Inactive includes system permission sheets; stop only on background.
                if newPhase == .background { store.setForeground(false) }
                guard newPhase == .active else { return }
                Task {
                    await store.refreshOnActivation()
                }
            }
    }
}
