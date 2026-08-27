import SwiftUI

struct SupportAndAboutSettingsSections: View {
    let showTipJar: () -> Void

    var body: some View {
        Section("Support") {
            Link(destination: .openAirSupportEmail) {
                Label("Email Support", systemImage: "envelope")
            }
            Link(destination: .appStoreReview) {
                Label("Rate OpenAir", systemImage: "star")
            }
            Link(destination: .githubRepo) {
                Label("Contribute on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button {
                showTipJar()
            } label: {
                Label("Leave a Tip", systemImage: "heart")
            }
        }

        Section {
            LabeledContent("Version", value: "\(String.appVersion) (\(String.buildNumber))")
            WeatherLegalLinkView()
        } header: {
            Text("About")
        } footer: {
            Text("OpenAir uses outdoor conditions only. It does not measure indoor temperature, humidity, air quality, or safety hazards.")
        }
    }
}
