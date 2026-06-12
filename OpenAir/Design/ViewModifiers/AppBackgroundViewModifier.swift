import SwiftUI

extension View {
    /// Applies OpenAir's full-screen app background to this view.
    ///
    /// The background uses a soft diagonal gradient that adapts to the current
    /// color scheme. Use this modifier on top-level screens that should share
    /// the app's standard background treatment.
    ///
    /// Example:
    /// ```swift
    /// DashboardContent()
    ///     .appBackground()
    /// ```
    func appBackground() -> some View {
        modifier(
            AppBackground()
        )
    }
}

private struct AppBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
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
    
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
    }
}
