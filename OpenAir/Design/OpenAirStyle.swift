import SwiftUI

enum OpenAirColor {
    static let navy = Color(red: 0.05, green: 0.16, blue: 0.28)
    static let teal = Color(red: 0.05, green: 0.55, blue: 0.60)
    static let mint = Color(red: 0.26, green: 0.84, blue: 0.68)
    static let green = Color(red: 0.05, green: 0.50, blue: 0.29)
    static let blue = Color(red: 0.10, green: 0.51, blue: 0.79)
    static let amber = Color(red: 0.86, green: 0.55, blue: 0.12)
    static let gray = Color(red: 0.42, green: 0.48, blue: 0.54)
}

extension RecommendationStatus {
    var color: Color {
        switch self {
        case .open: OpenAirColor.green
        case .keepClosed: OpenAirColor.gray
        }
    }

    var symbol: String {
        switch self {
        case .open: "window.vertical.open"
        case .keepClosed: "window.vertical.closed"
        }
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                OpenAirColor.teal.opacity(0.10),
                OpenAirColor.mint.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct WeatherCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemBackground).opacity(0.94),
                in: .rect(cornerRadius: 24)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.5), lineWidth: 0.5)
            }
            .shadow(color: OpenAirColor.navy.opacity(0.08), radius: 14, y: 6)
    }
}

struct StatusPill: View {
    let status: RecommendationStatus

    var body: some View {
        Label(status.shortTitle, systemImage: status.symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(status.color.opacity(0.12), in: .capsule)
            .accessibilityLabel("Recommendation: \(status.shortTitle)")
    }
}
