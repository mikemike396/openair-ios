import SwiftUI
import WidgetKit

struct OpenAirPhoneWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: OpenAirWidgetSnapshot?
}

struct OpenAirPhoneWidgetProvider: TimelineProvider {
    private let store = OpenAirWidgetSnapshotStore()

    func placeholder(in context: Context) -> OpenAirPhoneWidgetEntry {
        OpenAirPhoneWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (OpenAirPhoneWidgetEntry) -> Void
    ) {
        completion(OpenAirPhoneWidgetEntry(date: .now, snapshot: store.load() ?? .placeholder))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<OpenAirPhoneWidgetEntry>) -> Void
    ) {
        let entry = OpenAirPhoneWidgetEntry(date: .now, snapshot: store.load() ?? .placeholder)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct OpenAirPhoneWidget: Widget {
    let kind = "OpenAirPhoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenAirPhoneWidgetProvider()) { entry in
            OpenAirAccessoryCircularView(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("OpenAir")
        .description("Shows whether to open windows, plus temperature and dew point.")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct OpenAirWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OpenAirPhoneWidget()
    }
}
