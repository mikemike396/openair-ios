import StoreKit

final class TipTransactionObserver {
    private var observationTask: Task<Void, Never>?

    init() {
        observationTask = Task {
            await Self.observeTransactions()
        }
    }

    deinit {
        observationTask?.cancel()
    }

    private static func observeTransactions() async {
        for await result in Transaction.unfinished {
            guard !Task.isCancelled else { return }
            await finishRecognizedTransaction(result)
        }

        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            await finishRecognizedTransaction(result)
        }
    }

    private static func finishRecognizedTransaction(
        _ result: VerificationResult<Transaction>
    ) async {
        guard case .verified(let transaction) = result,
              TipProductID(rawValue: transaction.productID) != nil else {
            return
        }
        await transaction.finish()
    }
}
