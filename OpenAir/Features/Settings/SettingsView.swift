import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingTipJar = false

    var body: some View {
        NavigationStack {
            Form {
                LocationSettingsSection()
                ComfortSettingsSection()
                AlertSettingsSection()
                SupportAndAboutSettingsSections {
                    isShowingTipJar = true
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isShowingTipJar) {
            TipJarView()
        }
    }
}
