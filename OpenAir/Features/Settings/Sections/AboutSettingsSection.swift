import SwiftUI

struct AboutSettingsSection: View {
    var body: some View {
        Section("About") {
            Link(destination: .openAirSupportEmail) {
                LabeledContent("Support", value: String.openAirSupportEmail)
            }
            Link(destination: .githubRepo) {
                LabeledContent("Open source / contribute", value: "GitHub")
            }
            LabeledContent("Version", value: "\(String.appVersion) (\(String.buildNumber))")
            LabeledContent("Weather data", value: "Apple Weather")
            Text("OpenAir uses outdoor conditions only. It does not measure indoor temperature, humidity, air quality, or safety hazards.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
