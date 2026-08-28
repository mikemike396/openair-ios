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

struct WeatherCard<Content: View>: View {
    let contentPadding: CGFloat
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(cardOpacity))
                    .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
    }

    init(contentPadding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.contentPadding = contentPadding
        self.content = content()
    }

    private var cardOpacity: Double {
        colorScheme == .dark ? 0.94 : 0.91
    }

    private var shadowColor: Color {
        .openAirNavy.opacity(colorScheme == .dark ? 0.08 : 0.18)
    }

    private var shadowRadius: CGFloat {
        colorScheme == .dark ? 14 : 18
    }

    private var shadowYOffset: CGFloat {
        colorScheme == .dark ? 6 : 9
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.65)
            : .white.opacity(0.32)
    }

    private var borderWidth: CGFloat {
        colorScheme == .dark ? 0.75 : 0.5
    }
}
