import SwiftUI

struct OpenAirWatchStatusView: View {
    @State private var snapshot: OpenAirWidgetSnapshot?
    private let store = OpenAirWidgetSnapshotStore()

    var body: some View {
        GeometryReader { proxy in
            let scale = layoutScale(for: proxy.size.width)

            ScrollView {
                statusCard(scale: scale)
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
        .task {
            loadSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: OpenAirWidgetSnapshotStore.snapshotDidChangeNotification)) { _ in
            loadSnapshot()
        }
    }

    @ViewBuilder
    private func statusCard(scale: CGFloat) -> some View {
        if snapshot == nil {
            unsyncedContent(scale: scale)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header(scale: scale)
                Divider()
                content(scale: scale)
                updatedLine(scale: scale)
            }
            .padding(.vertical, 8 * scale)
            .padding(.horizontal, 8 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func unsyncedContent(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("OpenAir")
                    .font(.system(size: 17 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 24 * scale, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text("Open OpenAir on iPhone to sync latest conditions.")
                .font(.system(size: 12 * scale))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8 * scale)
        .padding(.horizontal, 8 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func header(scale: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(statusTitle)
                    .font(.system(size: 17 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .textCase(.uppercase)
                    .lineLimit(1)

                Text(snapshot?.locationName ?? "Waiting for iPhone")
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(.primary.opacity(0.72))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 6)

            statusSymbol
                .font(.system(size: 34 * scale, weight: .semibold))
                .foregroundStyle(statusColor)
        }
    }

    @ViewBuilder
    private func content(scale: CGFloat) -> some View {
        if let snapshot {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    metric(
                        snapshot.temperatureText,
                        systemImage: "cloud",
                        color: .primary,
                        scale: scale
                    )
                    Spacer(minLength: 4 * scale)
                    metric(
                        snapshot.dewPointText,
                        systemImage: "drop",
                        color: Color(.openAirBlue),
                        scale: scale
                    )
                    Spacer(minLength: 4 * scale)
                    metric(
                        "\(snapshot.windMPH) mph",
                        systemImage: "wind",
                        color: .primary,
                        scale: scale
                    )
                }

                HStack(spacing: 6 * scale) {
                    metric(
                        snapshot.temperatureText,
                        systemImage: "cloud",
                        color: .primary,
                        scale: scale
                    )
                    metric(
                        snapshot.dewPointText,
                        systemImage: "drop",
                        color: Color(.openAirBlue),
                        scale: scale
                    )
                    metric(
                        "\(snapshot.windMPH) mph",
                        systemImage: "wind",
                        color: .primary,
                        scale: scale
                    )
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)

            if let nextChangeText {
                Label(nextChangeText, systemImage: "clock")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        } else {
            Text("Open OpenAir on iPhone to sync the latest conditions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func updatedLine(scale: CGFloat) -> some View {
        if let snapshot {
            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 10 * scale, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4 * scale)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func metric(
        _ value: String,
        systemImage: String,
        color: Color,
        scale: CGFloat
    ) -> some View {
        HStack(spacing: 3 * scale) {
            Image(systemName: systemImage)
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private func layoutScale(for width: CGFloat) -> CGFloat {
        min(max(width / 170, 1), 1.22)
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

    private var nextChangeText: String? {
        guard let nextChange = snapshot?.nextChange else { return nil }
        return "Changes around \(nextChange.formatted(date: .omitted, time: .shortened)) \(nextChange.formatted(.dateTime.weekday(.wide)))"
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
