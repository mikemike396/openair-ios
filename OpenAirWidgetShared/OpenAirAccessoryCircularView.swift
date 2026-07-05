import SwiftUI
import WidgetKit

struct OpenAirAccessoryCircularView: View {
    let snapshot: OpenAirWidgetSnapshot?

    var body: some View {
        let snapshot = snapshot ?? .placeholder

        ZStack {
            AccessoryWidgetBackground()
            DewPointGauge(snapshot: snapshot)
                .padding(5)
        }
    }
}

private struct DewPointGauge: View {
    let snapshot: OpenAirWidgetSnapshot

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(size * 0.07, 2.5)

            ZStack {
                StatusArc()
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                VStack(spacing: 0) {
                    Text(snapshot.temperatureText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 1) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Color(.openAirBlue))
                        Text(snapshot.dewPointText)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.9))
                    }
                    .minimumScaleFactor(0.75)
                }
                .lineLimit(1)
                .offset(y: 1)
            }
        }
        .widgetAccentable()
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

private struct StatusArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let radius = size * 0.42
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(144),
            endAngle: .degrees(396),
            clockwise: false
        )
        return path
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
