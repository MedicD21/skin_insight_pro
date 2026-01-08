import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [StoreKit.Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Product IDs from App Store Connect
    private let productIDs: Set<String> = [
        "com.skininsightpro.solo.monthly",
        "com.skininsightpro.solo.annual",
        "com.skininsightpro.starter.monthly",
        "com.skininsightpro.starter.annual",
        "com.skininsightpro.professional.monthly",
        "com.skininsightpro.business.monthly",
        "com.skininsightpro.enterprise.monthly"
    ]

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await StoreKit.Product.products(for: Array(productIDs))

            // Sort products by price (lowest to highest)
            products = storeProducts.sorted { $0.price < $1.price }

            print("✅ Loaded \(products.count) products from App Store")

        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ Failed to load products: \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: StoreKit.Product) async throws -> Transaction? {
        guard let user = AuthenticationManager.shared.currentUser,
              let companyId = user.companyId,
              let isAdmin = user.isCompanyAdmin,
              isAdmin == true else {
            throw StoreError.notAuthorized
        }

        // Start the purchase
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)

            // Deliver content to the user
            await updatePurchasedProducts()

            // Always finish the transaction
            await transaction.finish()

            // Validate receipt with backend
            try await validateReceipt(transaction: transaction, companyId: companyId)

            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Check Subscription Status

    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if subscription is still active
                if let expirationDate = transaction.expirationDate,
                   expirationDate > Date() {
                    purchasedIDs.insert(transaction.productID)
                } else if transaction.expirationDate == nil {
                    // Non-renewable or lifetime purchase
                    purchasedIDs.insert(transaction.productID)
                }

            } catch {
                print("❌ Transaction verification failed: \(error)")
            }
        }

        purchasedProductIDs = purchasedIDs
        print("✅ Active subscriptions: \(purchasedIDs)")
    }

    // MARK: - Transaction Updates

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { @MainActor in
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Deliver content to the user
                    await self.updatePurchasedProducts()

                    // Always finish the transaction
                    await transaction.finish()

                } catch {
                    print("❌ Transaction update failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Receipt Validation

    private func validateReceipt(transaction: Transaction, companyId: String) async throws {
        // For iOS 18+, we use the transaction ID directly
        // For older versions, we'd use the receipt, but StoreKit 2 makes this simpler

        // Send transaction info to backend for validation
        // The backend will verify with Apple's server if needed
        try await NetworkService.shared.validateReceipt(
            receipt: String(transaction.id), // Use transaction ID as receipt identifier
            companyId: companyId,
            productId: transaction.productID,
            transactionId: String(transaction.id)
        )
    }

    // MARK: - Helper Methods

    func product(for id: String) -> StoreKit.Product? {
        products.first { $0.id == id }
    }

    func isSubscribed(to productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    func hasActiveSubscription() -> Bool {
        // GOD mode users always have access
        if AuthenticationManager.shared.currentUser?.godMode == true {
            return true
        }
        return !purchasedProductIDs.isEmpty
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case failedVerification
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .notAuthorized:
            return "Only company admins can purchase subscriptions"
        }
    }
}
