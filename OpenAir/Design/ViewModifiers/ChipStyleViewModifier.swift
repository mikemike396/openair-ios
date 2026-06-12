import SwiftUI

extension View {
    func chip() -> some View {
        modifier(
            ChipStyle()
        )
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
