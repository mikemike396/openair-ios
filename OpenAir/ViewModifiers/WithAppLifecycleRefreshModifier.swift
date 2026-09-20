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
            .alert("Weather where you are", isPresented: $store.showsBackgroundLocationExplanation) {
                Button("Continue") { store.dismissBackgroundLocationExplanation(requestAlways: true) }
                Button("Not Now", role: .cancel) { store.dismissBackgroundLocationExplanation(requestAlways: false) }
            } message: {
                Text("Allow “Always” location access to keep your weather, widgets, and window alerts updated as you travel.")
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
