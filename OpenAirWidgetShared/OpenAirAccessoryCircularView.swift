import SwiftUI
import WidgetKit

struct OpenAirAccessoryCircularView: View {
    let snapshot: OpenAirWidgetSnapshot?

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let snapshot {
                VStack(spacing: 0) {
                    Image(systemName: snapshot.status.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(snapshot.status.tint)
                    Text(snapshot.temperatureText)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    HStack(spacing: 1) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8, weight: .semibold))
                        Text(snapshot.dewPointText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                }
                .widgetAccentable()
                .padding(5)
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "window.vertical.closed")
                        .font(.system(size: 15, weight: .semibold))
                    Text("--")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .foregroundStyle(.secondary)
                .padding(5)
            }
        }
    }
}

extension OpenAirWidgetSnapshot {
    static let placeholder = OpenAirWidgetSnapshot(
        status: .open,
        temperature: 72,
        dewPoint: 58,
        unitSymbol: "°F",
        fetchedAt: .now,
        locationName: "Preview"
    )

    var temperatureText: String {
        "\(temperature)°"
    }

    var dewPointText: String {
        "\(dewPoint)°"
    }
}

private extension OpenAirWidgetRecommendationStatus {
    var tint: Color {
        switch self {
        case .open: .green
        case .keepClosed: .red
        }
    }
}
