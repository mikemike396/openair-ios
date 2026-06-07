import Foundation

extension String {
    static let backgroundRefreshTaskIdentifier = "com.openairapp.openair.refresh"
    static let openAirSupportEmail = "openairappsupport@gmail.com"
    
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
