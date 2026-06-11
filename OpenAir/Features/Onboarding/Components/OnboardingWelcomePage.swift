import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: 28) {
            Text("OpenAir")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.openAirBrandText)
                .minimumScaleFactor(0.85)
                .lineLimit(1)

            Text("Know when to open your windows.")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)

            Text("OpenAir evaluates outdoor temperature, dew point, rain, and wind. It does not measure or compare your indoor air.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
