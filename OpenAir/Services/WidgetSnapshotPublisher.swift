import Foundation
import WidgetKit

#if os(iOS)
import WatchConnectivity
#endif

@MainActor
protocol WidgetSnapshotPublishing {
    func publish(
        weather: WeatherSnapshot,
        plan: RecommendationPlan,
        preferences: ComfortPreferences
    )
}

@MainActor
final class WidgetSnapshotPublisher: WidgetSnapshotPublishing {
    private let factory: WidgetSnapshotFactory
    private let store: OpenAirWidgetSnapshotStore
    private let watchSync: WatchSnapshotSyncing

    init(
        factory: WidgetSnapshotFactory = WidgetSnapshotFactory(),
        store: OpenAirWidgetSnapshotStore = OpenAirWidgetSnapshotStore(),
        watchSync: WatchSnapshotSyncing = WatchSnapshotSyncClient()
    ) {
        self.factory = factory
        self.store = store
        self.watchSync = watchSync
    }

    func publish(
        weather: WeatherSnapshot,
        plan: RecommendationPlan,
        preferences: ComfortPreferences
    ) {
        let snapshot = factory.makeSnapshot(weather: weather, plan: plan, preferences: preferences)
        store.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        watchSync.send(snapshot)
    }
}

struct DisabledWidgetSnapshotPublisher: WidgetSnapshotPublishing {
    func publish(
        weather: WeatherSnapshot,
        plan: RecommendationPlan,
        preferences: ComfortPreferences
    ) {}
}

@MainActor
protocol WatchSnapshotSyncing {
    func send(_ snapshot: OpenAirWidgetSnapshot)
}

struct DisabledWatchSnapshotSyncClient: WatchSnapshotSyncing {
    func send(_ snapshot: OpenAirWidgetSnapshot) {}
}

#if os(iOS)
@MainActor
final class WatchSnapshotSyncClient: NSObject, WatchSnapshotSyncing, WCSessionDelegate {
    private var pendingSnapshot: OpenAirWidgetSnapshot?
    private let session: WCSession?

    override convenience init() {
        self.init(session: WCSession.isSupported() ? .default : nil)
    }

    init(session: WCSession?) {
        self.session = session
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func send(_ snapshot: OpenAirWidgetSnapshot) {
        guard let session, session.activationState == .activated else {
            pendingSnapshot = snapshot
            return
        }
        send(snapshot, through: session)
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            guard activationState == .activated else { return }
            flushPendingSnapshot()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    private func flushPendingSnapshot() {
        guard let session, let snapshot = pendingSnapshot else { return }
        pendingSnapshot = nil
        send(snapshot, through: session)
    }

    private func send(_ snapshot: OpenAirWidgetSnapshot, through session: WCSession) {
        guard let data = OpenAirWidgetSnapshotStore.encoded(snapshot) else { return }
        let userInfo = [OpenAirWidgetSnapshotStore.watchTransferSnapshotDataKey: data]
        try? session.updateApplicationContext(userInfo)
        session.transferUserInfo(userInfo)

        if session.isReachable {
            session.sendMessage(userInfo, replyHandler: nil)
        }

        if session.isComplicationEnabled {
            session.transferCurrentComplicationUserInfo(userInfo)
        }
    }
}
#else
struct WatchSnapshotSyncClient: WatchSnapshotSyncing {
    func send(_ snapshot: OpenAirWidgetSnapshot) {}
}
#endif
