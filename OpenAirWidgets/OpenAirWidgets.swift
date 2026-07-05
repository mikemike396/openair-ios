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
            OpenAirPhoneWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("OpenAir")
        .description("Shows whether to open windows, plus temperature and dew point.")
        .supportedFamilies([.accessoryCircular, .systemMedium])
    }
}

private struct OpenAirPhoneWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: OpenAirWidgetSnapshot?

    var body: some View {
        switch family {
        case .systemMedium:
            OpenAirMediumWidgetView(snapshot: snapshot ?? .placeholder)
                .containerBackground(for: .widget) {
                    Color(.secondarySystemBackground)
                }
        default:
            OpenAirAccessoryCircularView(snapshot: snapshot)
                .containerBackground(.clear, for: .widget)
        }
    }
}

private struct OpenAirMediumWidgetView: View {
    let snapshot: OpenAirWidgetSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)

                    Text(snapshot.locationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let nextChangeText {
                    Label(nextChangeText, systemImage: "clock")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                } else {
                    Text(statusSummary)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    metric(snapshot.temperatureText, systemImage: "cloud")
                    metric("DP \(snapshot.dewPointText)", systemImage: "drop")
                    metric("\(snapshot.windMPH) mph", systemImage: "wind")
                }
                .lineLimit(1)

                Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: snapshot.status.symbolName)
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(statusColor)
                .accessibilityHidden(true)
        }
        .padding(16)
    }

    private func metric(_ value: String, systemImage: String) -> some View {
        Label {
            Text(value)
                .font(.caption.weight(.semibold))
                .minimumScaleFactor(0.75)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(systemImage == "drop" ? Color(.openAirBlue) : .primary)
        }
    }

    private var statusTitle: String {
        switch snapshot.status {
        case .open: "OPEN"
        case .keepClosed: "CLOSED"
        }
    }

    private var statusSummary: String {
        switch snapshot.status {
        case .open: "Outdoor conditions are comfortable."
        case .keepClosed: "Outdoor conditions are unfavorable."
        }
    }

    private var nextChangeText: String? {
        guard let nextChange = snapshot.nextChange else { return nil }
        return "Expected to change around \(nextChange.formatted(date: .omitted, time: .shortened)) \(nextChange.formatted(.dateTime.weekday(.wide)))"
    }

    private var statusColor: Color {
        switch snapshot.status {
        case .open:
            Color(.openAirWidgetOpen)
        case .keepClosed:
            Color(.openAirWidgetClosed)
        }
    }
}

@main
struct OpenAirWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OpenAirPhoneWidget()
    }
}
