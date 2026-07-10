import SwiftUI
import WidgetKit

struct OpenAirAccessoryCircularView: View {
    let snapshot: OpenAirWidgetSnapshot?

    var body: some View {
        let snapshot = snapshot ?? .placeholder

        ZStack {
            AccessoryWidgetBackground()
            CircularStatusFace(snapshot: snapshot)
        }
    }
}

private struct CircularStatusFace: View {
    let snapshot: OpenAirWidgetSnapshot

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(size * 0.065, 2.25)
            let temperatureFontSize = min(max(size * 0.34, 13), 17)
            let dewPointFontSize = min(max(size * 0.19, 7.5), 9.5)
            let dewPointIconSize = min(max(size * 0.155, 6.5), 8)

            ZStack {
                StatusArc()
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                VStack(spacing: -1) {
                    Text(snapshot.temperatureText)
                        .font(.system(size: temperatureFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 1) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: dewPointIconSize, weight: .bold))
                            .foregroundStyle(Color(.openAirBlue))
                        Text(snapshot.dewPointText)
                            .font(.system(size: dewPointFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.9))
                    }
                    .minimumScaleFactor(0.7)
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
        let radius = size * 0.46
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
        windMPH: 5,
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
