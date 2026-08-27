import SwiftUI

struct AboutSettingsSection: View {
    let showTipJar: () -> Void

    var body: some View {
        Section("About") {
            Link(destination: .openAirSupportEmail) {
                LabeledContent("Support", value: String.openAirSupportEmail)
            }
            Link(destination: .githubRepo) {
                LabeledContent("Open source / contribute", value: "GitHub")
            }
            Link(destination: .appStoreReview) {
                LabeledContent("Rate OpenAir", value: "App Store")
            }
            Button {
                showTipJar()
            } label: {
                LabeledContent("Support OpenAir", value: "Leave a tip")
            }
            LabeledContent("Version", value: "\(String.appVersion) (\(String.buildNumber))")
            WeatherLegalLinkView()
            Text("OpenAir uses outdoor conditions only. It does not measure indoor temperature, humidity, air quality, or safety hazards.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
