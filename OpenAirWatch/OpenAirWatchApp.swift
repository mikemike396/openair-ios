import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct OpenAirWatchApp: App {
    @State private var model: WatchSnapshotModel
    @State private var receiver: WatchSnapshotReceiver

    init() {
        let model = WatchSnapshotModel()
        _model = State(initialValue: model)
        _receiver = State(initialValue: WatchSnapshotReceiver(model: model))
    }

    var body: some Scene {
        WindowGroup {
            OpenAirWatchStatusView(model: model)
                .task {
                    receiver.start()
                }
        }
        .backgroundTask(.watchConnectivity) {
            await receiver.handleWatchConnectivityBackgroundTask()
        }
    }
}

@Observable
@MainActor
final class WatchSnapshotModel {
    private let store: OpenAirWidgetSnapshotStore
    private(set) var snapshot: OpenAirWidgetSnapshot?

    init(store: OpenAirWidgetSnapshotStore = OpenAirWidgetSnapshotStore()) {
        self.store = store
    }

    func loadSnapshot() {
        snapshot = store.load()
    }

    func saveSnapshot(data: Data) {
        store.save(data: data)
        loadSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

@MainActor
final class WatchSnapshotReceiver: NSObject, WCSessionDelegate {
    private var session: WCSession?
    private let model: WatchSnapshotModel

    init(model: WatchSnapshotModel) {
        self.model = model
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
    ) {
        guard activationState == .activated else { return }
        saveSnapshot(from: session.receivedApplicationContext)
    }

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
        Task { @MainActor [weak self] in
            self?.model.saveSnapshot(data: data)
        }
    }
}
