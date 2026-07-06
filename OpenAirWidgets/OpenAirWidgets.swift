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
        .supportedFamilies([.accessoryCircular, .systemSmall, .systemMedium])
    }
}

private struct OpenAirPhoneWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: OpenAirWidgetSnapshot?

    var body: some View {
        switch family {
        case .systemSmall:
            OpenAirSmallWidgetView(snapshot: snapshot ?? .placeholder)
                .containerBackground(for: .widget) {
                    OpenAirMediumWidgetBackground()
                }
        case .systemMedium:
            OpenAirMediumWidgetView(snapshot: snapshot ?? .placeholder)
                .containerBackground(for: .widget) {
                    OpenAirMediumWidgetBackground()
                }
        default:
            OpenAirAccessoryCircularView(snapshot: snapshot)
                .containerBackground(.clear, for: .widget)
        }
    }
}

private struct OpenAirMediumWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            Color.black
        } else {
            Color(uiColor: .secondarySystemBackground)
                .opacity(0.91)
        }
    }
}

private struct OpenAirSmallWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: OpenAirWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                Text(statusTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                Image(systemName: snapshot.status.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)
            }

            Text(snapshot.locationName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(2)

            Spacer(minLength: nextChangeText == nil ? 6 : 0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    compactMetric(snapshot.temperatureText, systemImage: snapshot.conditionSymbolName)
                    compactMetric(snapshot.dewPointText, systemImage: "drop")
                }

                HStack {
                    compactMetric("\(snapshot.windMPH) mph", systemImage: "wind")
                    Spacer(minLength: 0)
                }
            }
            .lineLimit(1)

            if let nextChangeText {
                Label(nextChangeText, systemImage: "clock")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .padding(0)
    }

    private func compactMetric(_ value: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(systemImage == "drop" ? Color(.openAirBlue) : .primary)
                .frame(width: 16, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .minimumScaleFactor(0.75)
        }
    }

    private var statusTitle: String {
        snapshot.widgetStatusTitle
    }

    private var nextChangeText: String? {
        snapshot.shortNextChangeText
    }

    private var statusColor: Color {
        snapshot.widgetStatusColor
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.72) : .secondary
    }
}

private struct OpenAirMediumWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: OpenAirWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(snapshot.locationName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Image(systemName: snapshot.status.symbolName)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)
            }

            if let nextChangeText {
                Label(nextChangeText, systemImage: "clock")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            HStack(spacing: 0) {
                metric(snapshot.temperatureText, systemImage: snapshot.conditionSymbolName)
                Spacer(minLength: 12)
                metric(snapshot.dewPointText, systemImage: "drop")
                Spacer(minLength: 12)
                metric("\(snapshot.windMPH) mph", systemImage: "wind")
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)

            Spacer(minLength: 0)

            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .padding(8)
    }

    private func metric(_ value: String, systemImage: String) -> some View {
        Label {
            Text(value)
                .font(.body.weight(.semibold))
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: true, vertical: false)
        } icon: {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(systemImage == "drop" ? Color(.openAirBlue) : .primary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var statusTitle: String {
        snapshot.widgetStatusTitle
    }

    private var nextChangeText: String? {
        snapshot.longNextChangeText
    }

    private var statusColor: Color {
        snapshot.widgetStatusColor
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.72) : .secondary
    }
}

private extension OpenAirWidgetSnapshot {
    var widgetStatusTitle: String {
        switch status {
        case .open: "OPEN"
        case .keepClosed: "CLOSED"
        }
    }

    var widgetStatusColor: Color {
        switch status {
        case .open:
            Color(.openAirWidgetOpen)
        case .keepClosed:
            Color(.openAirWidgetClosed)
        }
    }

    var shortNextChangeText: String? {
        guard let nextChange else { return nil }
        let timeText = Calendar.current.component(.minute, from: nextChange) == 0
            ? nextChange.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            : nextChange.formatted(date: .omitted, time: .shortened)
        return "Changes \(timeText) \(nextChange.formatted(.dateTime.weekday(.abbreviated)))"
    }

    var longNextChangeText: String? {
        guard let nextChange else { return nil }
        return "Changes around \(nextChange.formatted(date: .omitted, time: .shortened)) \(nextChange.formatted(.dateTime.weekday(.wide)))"
    }
}

@main
struct OpenAirWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OpenAirPhoneWidget()
    }
}
