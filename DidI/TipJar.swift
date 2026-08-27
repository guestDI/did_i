import StoreKit

/// One consumable tip, no entitlement, nothing persisted. This class exists
/// purely to hide StoreKit's verification/finish bookkeeping from the UI —
/// `SettingsView` only ever sees `product` and calls `purchase()`.
@Observable
@MainActor
final class TipJar {
    static let shared = TipJar()

    static let productID = "com.dihnatovich.didi.tip.small"

    private(set) var product: Product?

    private init() {}

    func loadProduct() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    /// Returns `true` on a completed purchase, `false` if the user cancelled.
    /// Any other outcome (verification failure, pending/ask-to-buy, StoreKit
    /// error) throws so the caller can show an error.
    func purchase() async throws -> Bool {
        guard let product else {
            await loadProduct()
            guard let product else { throw TipJarError.productUnavailable }
            return try await purchase(product)
        }
        return try await purchase(product)
    }

    private func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verify(verification)
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Started once at launch. Catches transactions that finished outside a
    /// direct `purchase()` call in this session — e.g. the app was killed
    /// between StoreKit completing the purchase and `finish()` being called.
    /// Without this, an unfinished transaction is redelivered by StoreKit on
    /// every future launch.
    func startListeningForTransactionUpdates() {
        Task.detached {
            for await update in Transaction.updates {
                if let transaction = try? self.verify(update) {
                    await transaction.finish()
                }
            }
        }
    }

    nonisolated private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TipJarError.unverifiedTransaction
        case .verified(let value):
            return value
        }
    }
}

enum TipJarError: Error {
    case productUnavailable
    case unverifiedTransaction
}
