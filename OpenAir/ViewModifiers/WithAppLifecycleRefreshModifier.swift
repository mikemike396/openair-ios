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
