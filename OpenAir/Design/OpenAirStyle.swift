import SwiftUI

extension RecommendationStatus {
    var color: Color {
        switch self {
        case .open: .openAirGreen
        case .keepClosed: .openAirGray
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var colors: [Color] {
        if colorScheme == .dark {
            [
                Color(red: 0.04, green: 0.08, blue: 0.11),
                Color(red: 0.05, green: 0.18, blue: 0.19),
                Color(red: 0.07, green: 0.13, blue: 0.18)
            ]
        } else {
            [
                Color(red: 0.94, green: 0.98, blue: 0.98),
                Color.openAirTeal.opacity(0.12),
                Color.openAirMint.opacity(0.10)
            ]
        }
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
            .shadow(color: .openAirNavy.opacity(0.08), radius: 14, y: 6)
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
