import SwiftUI

struct OpenAirWatchStatusView: View {
    @State private var snapshot: OpenAirWidgetSnapshot?
    private let store = OpenAirWidgetSnapshotStore()

    var body: some View {
        ScrollView {
            statusCard
                .padding(.horizontal, 4)
        }
        .task {
            loadSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: OpenAirWidgetSnapshotStore.snapshotDidChangeNotification)) { _ in
            loadSnapshot()
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            content
            updatedLine
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(statusTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .textCase(.uppercase)
                    .lineLimit(1)

                Text(statusSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(snapshot?.locationName ?? "Waiting for iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            statusSymbol
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(statusColor)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot {
            HStack(spacing: 6) {
                metric(
                    snapshot.temperatureText,
                    systemImage: "cloud",
                    color: .primary
                )
                Spacer(minLength: 0)
                metric(
                    "DP \(snapshot.dewPointText)",
                    systemImage: "drop",
                    color: Color(.openAirBlue)
                )
                Spacer(minLength: 0)
                metric(
                    "\(snapshot.windMPH) mph",
                    systemImage: "wind",
                    color: .primary
                )
            }
            .lineLimit(1)
        } else {
            Text("Open OpenAir on iPhone to sync the latest conditions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var updatedLine: some View {
        if let snapshot {
            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func metric(
        _ value: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.65)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
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

    private var statusSummary: String {
        switch snapshot?.status {
        case .open:
            "Outdoor conditions are comfortable."
        case .keepClosed:
            "Outdoor conditions are unfavorable."
        case nil:
            "Sync latest conditions."
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
