import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct OpenAirWatchApp: App {
    @State private var receiver = WatchSnapshotReceiver()

    var body: some Scene {
        WindowGroup {
            OpenAirWatchStatusView()
                .task {
                    receiver.start()
                }
        }
        .backgroundTask(.watchConnectivity) {
            await receiver.handleWatchConnectivityBackgroundTask()
        }
    }
}

struct OpenAirWatchStatusView: View {
    @State private var snapshot: OpenAirWidgetSnapshot?
    private let store = OpenAirWidgetSnapshotStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    statusSymbol
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(statusColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(statusTitle)
                            .font(.headline)
                            .foregroundStyle(statusColor)
                        Text(snapshot?.locationName ?? "Waiting for iPhone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let snapshot {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(snapshot.temperatureText)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.7)

                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(.openAirBlue))
                            Text(snapshot.dewPointText)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                    }
                    .lineLimit(1)

                    Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Open OpenAir on iPhone to sync the latest conditions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .task {
            loadSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: OpenAirWidgetSnapshotStore.snapshotDidChangeNotification)) { _ in
            loadSnapshot()
        }
    }

    private var statusTitle: String {
        switch snapshot?.status {
        case .open:
            "Open"
        case .keepClosed:
            "Closed"
        case nil:
            "OpenAir"
        }
    }

    private var statusSymbol: Image {
        switch snapshot?.status {
        case .open:
            Image(systemName: "window.vertical.open")
        case .keepClosed:
            Image(systemName: "window.vertical.closed")
        case nil:
            Image(systemName: "iphone.radiowaves.left.and.right")
        }
    }

    private var statusColor: Color {
        switch snapshot?.status {
        case .open:
            Color(.openAirWidgetOpen)
        case .keepClosed:
            Color(.openAirWidgetClosed)
        case nil:
            .secondary
        }
    }

    private func loadSnapshot() {
        snapshot = store.load()
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
