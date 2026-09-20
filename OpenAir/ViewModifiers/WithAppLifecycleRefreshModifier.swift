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
        @Bindable var store = store
        content
            .task {
                if scenePhase == .active { await store.start() }
            }
            .alert("Keep weather local as you travel", isPresented: $store.showsBackgroundLocationExplanation) {
                Button("Continue") { store.dismissBackgroundLocationExplanation(requestAlways: true) }
                Button("Not Now", role: .cancel) { store.dismissBackgroundLocationExplanation(requestAlways: false) }
            } message: {
                Text("Allow location access Always so OpenAir can update your weather, widgets, and window alerts when you travel, even when the app is closed. You can keep using automatic location while the app is open without Always access.")
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
