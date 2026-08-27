import StoreKit
import SwiftUI

struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alert: TipJarAlert?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Support OpenAir")
                        .font(.title2.bold())
                    Text("OpenAir is free and open source. Tips support ongoing development and do not unlock features.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                StoreView(ids: TipProductID.allIdentifiers)
                .productViewStyle(.compact)
                .productDescription(.hidden)
                .storeButton(.hidden, for: .restorePurchases, .cancellation)

                Spacer(minLength: 0)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onInAppPurchaseCompletion { product, result in
                guard TipProductID(rawValue: product.id) != nil else { return }
                let outcome = await process(result)
                if let purchaseAlert = outcome.alert {
                    alert = purchaseAlert
                }
            }
            .alert(item: $alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func process(
        _ result: Result<Product.PurchaseResult, any Error>
    ) async -> TipPurchaseOutcome {
        switch result {
        case .failure:
            return .failed
        case .success(let purchaseResult):
            switch purchaseResult {
            case .success(let verificationResult):
                guard case .verified(let transaction) = verificationResult else {
                    return .failed
                }
                await transaction.finish()
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        }
    }
}
