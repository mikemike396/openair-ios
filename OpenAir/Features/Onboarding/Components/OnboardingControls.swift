import SwiftUI

struct OnboardingControls: View {
    let page: Int
    let canContinue: Bool
    let goBack: () -> Void
    let continueForward: () -> Void
    let complete: () -> Void

    var body: some View {
        HStack {
            if page > 0 {
                Button("Back", action: goBack)
                    .buttonStyle(.glass)
            }

            Spacer()

            if page < 2 {
                Button("Continue", action: continueForward)
                    .buttonStyle(.glassProminent)
                    .disabled(!canContinue)
            } else {
                Button("Get Started", action: complete)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("completeOnboardingButton")
            }
        }
    }
}
