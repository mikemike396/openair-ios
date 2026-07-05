import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct OpenAirWatchApp: App {
    @State private var receiver = WatchSnapshotReceiver()

    var body: some Scene {
        WindowGroup {
            Text("OpenAir")
                .task {
                    receiver.start()
                }
        }
        .backgroundTask(.watchConnectivity) {
            await receiver.handleWatchConnectivityBackgroundTask()
        }
    }
}

@MainActor
final class WatchSnapshotReceiver: NSObject, WCSessionDelegate {
    private let store: OpenAirWidgetSnapshotStore
    private var session: WCSession?

    init(store: OpenAirWidgetSnapshotStore = OpenAirWidgetSnapshotStore()) {
        self.store = store
    }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
        saveSnapshot(from: session.receivedApplicationContext)
    }

    func handleWatchConnectivityBackgroundTask() async {
        start()
        try? await Task.sleep(for: .seconds(2))
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        saveSnapshot(from: userInfo)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        saveSnapshot(from: applicationContext)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        saveSnapshot(from: message)
    }

    private nonisolated func saveSnapshot(from payload: [String: Any]) {
        guard let data = payload[OpenAirWidgetSnapshotStore.watchTransferSnapshotDataKey] as? Data else { return }
        Task { @MainActor in
            self.store.save(data: data)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
