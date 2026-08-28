import Foundation

enum TipProductID: String, CaseIterable, Sendable {
    case small = "com.openairapp.openair.tip.small"
    case medium = "com.openairapp.openair.tip.medium"
    case large = "com.openairapp.openair.tip.large"

    static var allIdentifiers: [String] {
        allCases.map(\.rawValue)
    }
}
