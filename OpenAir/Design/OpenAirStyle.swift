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
                Color(red: 0.95, green: 0.99, blue: 0.98),
                Color.openAirTeal.opacity(0.11),
                Color.openAirMint.opacity(0.08)
            ]
        }
    }
}

struct WeatherCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemBackground).opacity(cardOpacity),
                in: .rect(cornerRadius: 24)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
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

private struct ChipStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(fill, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(stroke, lineWidth: 0.5)
            }
    }

    private var fill: Color {
        colorScheme == .dark
            ? .white.opacity(0.10)
            : .openAirNavy.opacity(0.07)
    }

    private var stroke: Color {
        colorScheme == .dark
            ? .white.opacity(0.12)
            : .openAirNavy.opacity(0.06)
    }
}

private struct PanelStyle: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(fill, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(stroke, lineWidth: 0.5)
            }
    }

    private var fill: Color {
        colorScheme == .dark
            ? .white.opacity(0.08)
            : .openAirNavy.opacity(0.06)
    }

    private var stroke: Color {
        colorScheme == .dark
            ? .white.opacity(0.10)
            : .openAirNavy.opacity(0.05)
    }
}

extension View {
    func chip() -> some View {
        modifier(
            ChipStyle()
        )
    }

    func panel(cornerRadius: CGFloat) -> some View {
        modifier(
            PanelStyle(
                cornerRadius: cornerRadius
            )
        )
    }
}
