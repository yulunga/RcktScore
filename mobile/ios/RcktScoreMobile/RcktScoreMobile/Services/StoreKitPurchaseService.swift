import Foundation
import Combine
import StoreKit

@MainActor
final class StoreKitPurchaseService: ObservableObject {
    static let monthlyProductID = "com.hitnscore.personalplus.monthly"
    static let yearlyProductID = "com.hitnscore.personalplus.yearly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var activeProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = observeTransactionUpdates()
        Task { await refreshCurrentEntitlements() }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var canRunLocalPurchases: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    func loadProducts(force: Bool = false) async {
        guard force || products.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loadedProducts = try await Product.products(for: [
                Self.monthlyProductID,
                Self.yearlyProductID
            ])
            products = loadedProducts.sorted { productOrder($0.id) < productOrder($1.id) }

            if products.count != 2 {
                let loadedIDs = Set(products.map(\.id))
                let missingIDs = [Self.monthlyProductID, Self.yearlyProductID]
                    .filter { !loadedIDs.contains($0) }
                errorMessage = "Unable to load: \(missingIDs.joined(separator: ", ")). Check the active StoreKit configuration."
            }
        } catch {
            errorMessage = "Unable to load Personal Plus subscriptions: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        guard canRunLocalPurchases else {
            errorMessage = "Purchasing is disabled until backend App Store verification is deployed."
            return
        }
        guard [Self.monthlyProductID, Self.yearlyProductID].contains(product.id) else {
            errorMessage = "This subscription product is not supported."
            return
        }

        purchasingProductID = product.id
        statusMessage = nil
        errorMessage = nil
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                let transaction = try verified(verificationResult)
                await recordLocalTestTransaction(transaction)
                await transaction.finish()
                await refreshCurrentEntitlements()
                statusMessage = "Test purchase completed. Your server account has not been upgraded because backend Apple verification is not connected yet."
            case .pending:
                statusMessage = "The purchase is pending approval or payment confirmation."
            case .userCancelled:
                statusMessage = "Purchase cancelled."
            @unknown default:
                errorMessage = "The App Store returned an unknown purchase result."
            }
        } catch {
            errorMessage = "Unable to complete the purchase: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        guard canRunLocalPurchases else {
            errorMessage = "Restore Purchases is disabled until backend App Store verification is deployed."
            return
        }

        statusMessage = nil
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshCurrentEntitlements()
            statusMessage = activeProductIDs.isEmpty
                ? "No active Personal Plus test subscription was found."
                : "Active Personal Plus test subscription restored."
        } catch {
            errorMessage = "Unable to restore purchases: \(error.localizedDescription)"
        }
    }

    func refreshCurrentEntitlements() async {
        var currentProductIDs: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  [Self.monthlyProductID, Self.yearlyProductID].contains(transaction.productID),
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true
            else {
                continue
            }
            currentProductIDs.insert(transaction.productID)
        }
        activeProductIDs = currentProductIDs
    }

    func planName(for product: Product) -> String {
        switch product.id {
        case Self.monthlyProductID:
            return "Monthly"
        case Self.yearlyProductID:
            return "Yearly"
        default:
            return product.displayName
        }
    }

    func planDetail(for product: Product) -> String {
        switch product.id {
        case Self.monthlyProductID:
            return "Billed monthly through your Apple Account."
        case Self.yearlyProductID:
            return "Billed yearly through your Apple Account."
        default:
            return "Personal Plus subscription."
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(update)
                    guard [Self.monthlyProductID, Self.yearlyProductID].contains(transaction.productID) else {
                        continue
                    }
                    await self.recordLocalTestTransaction(transaction)
                    await transaction.finish()
                    await self.refreshCurrentEntitlements()
                } catch {
                    self.errorMessage = "An App Store transaction could not be verified on this device."
                }
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw StoreKitPurchaseError.unverified(error)
        }
    }

    private func recordLocalTestTransaction(_ transaction: Transaction) async {
        // Local StoreKit testing deliberately does not change the backend plan.
        // Production must send the signed JWS plus a server-issued appAccountToken
        // to the backend and wait for authoritative entitlement activation here.
        activeProductIDs.insert(transaction.productID)
    }

    private func productOrder(_ productID: String) -> Int {
        productID == Self.monthlyProductID ? 0 : 1
    }
}

private enum StoreKitPurchaseError: LocalizedError {
    case unverified(Error)

    var errorDescription: String? {
        switch self {
        case .unverified(let error):
            return "The App Store transaction could not be verified: \(error.localizedDescription)"
        }
    }
}
