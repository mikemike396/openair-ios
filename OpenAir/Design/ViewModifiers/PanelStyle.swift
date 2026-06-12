import SwiftUI

extension View {
    func panel(cornerRadius: CGFloat) -> some View {
        modifier(
            PanelStyle(
                cornerRadius: cornerRadius
            )
        )
    }
}

private struct PanelStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

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
    
    func body(content: Content) -> some View {
        content
            .background(fill, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(stroke, lineWidth: 0.5)
            }
    }
}
