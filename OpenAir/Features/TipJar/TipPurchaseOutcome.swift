import Foundation

enum TipPurchaseOutcome: Equatable, Sendable {
    case purchased
    case pending
    case cancelled
    case failed

    var alert: TipJarAlert? {
        switch self {
        case .purchased:
            TipJarAlert(
                title: "Thank You",
                message: "Your support helps keep OpenAir improving."
            )
        case .pending:
            TipJarAlert(
                title: "Tip Pending",
                message: "The App Store will complete your tip after it is approved."
            )
        case .failed:
            TipJarAlert(
                title: "Tip Not Completed",
                message: "The purchase could not be verified. Please try again."
            )
        case .cancelled:
            nil
        }
    }
}

struct TipJarAlert: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let message: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title && lhs.message == rhs.message
    }
}
