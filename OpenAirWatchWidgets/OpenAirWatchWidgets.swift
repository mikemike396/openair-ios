import SwiftUI
import WatchConnectivity
import WidgetKit

struct OpenAirComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: OpenAirWidgetSnapshot?
}

struct OpenAirComplicationProvider: TimelineProvider {
    private let store = OpenAirWidgetSnapshotStore()

    func placeholder(in context: Context) -> OpenAirComplicationEntry {
        OpenAirComplicationEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (OpenAirComplicationEntry) -> Void
    ) {
        completion(OpenAirComplicationEntry(date: .now, snapshot: loadSnapshot() ?? .placeholder))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<OpenAirComplicationEntry>) -> Void
    ) {
        let entry = OpenAirComplicationEntry(date: .now, snapshot: loadSnapshot() ?? .placeholder)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> OpenAirWidgetSnapshot? {
        saveLatestApplicationContextIfAvailable()
        return store.load()
    }

    private func saveLatestApplicationContextIfAvailable() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState == .notActivated {
            session.activate()
        }
        guard let data = session.receivedApplicationContext[OpenAirWidgetSnapshotStore.watchTransferSnapshotDataKey] as? Data else {
            return
        }
        _ = store.save(data: data)
    }
}

struct OpenAirComplicationWidget: Widget {
    let kind = "OpenAirComplicationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenAirComplicationProvider()) { entry in
            OpenAirAccessoryCircularView(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("OpenAir")
        .description("Shows whether to open windows, plus temperature and dew point.")
        .supportedFamilies([.accessoryCircular])
        .contentMarginsDisabled()
    }
}

@main
struct OpenAirWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OpenAirComplicationWidget()
    }
}
