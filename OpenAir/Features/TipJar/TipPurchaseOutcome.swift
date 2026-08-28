import Foundation

enum TipPurchaseOutcome: Equatable, Sendable {
    case purchased
    case pending
    case cancelled
    case failed

    var alert: TipPurchaseAlert? {
        switch self {
        case .purchased:
            .thankYou
        case .pending:
            .pending
        case .failed:
            .failed
        case .cancelled:
            nil
        }
    }
}

enum TipPurchaseAlert: Identifiable, Equatable, Sendable {
    case thankYou
    case pending
    case failed

    var id: Self { self }

    var title: String {
        switch self {
        case .thankYou: "Thank You"
        case .pending: "Tip Pending"
        case .failed: "Tip Not Completed"
        }
    }

    var message: String {
        switch self {
        case .thankYou:
            "Your support helps maintain and improve OpenAir."
        case .pending:
            "The App Store will complete your tip after it is approved."
        case .failed:
            "The tip could not be completed. Please try again."
        }
    }
}
