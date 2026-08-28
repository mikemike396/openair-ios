import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingTipView = false

    var body: some View {
        NavigationStack {
            Form {
                LocationSettingsSection()
                ComfortSettingsSection()
                AlertSettingsSection()
                SupportAndAboutSettingsSections {
                    isShowingTipView = true
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
        .sheet(isPresented: $isShowingTipView) {
            TipView()
        }
    }
}
