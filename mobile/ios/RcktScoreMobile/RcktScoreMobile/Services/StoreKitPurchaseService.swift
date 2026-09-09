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
    @Published private(set) var purchasesEnabled = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?
    private weak var apiClient: APIClient?
    private var organizationIDProvider: (() -> Int?)?
    private var purchaseContext: AppleSubscriptionContext?

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
        purchasesEnabled
#endif
    }

    func configure(
        apiClient: APIClient,
        organizationIDProvider: @escaping () -> Int?
    ) {
        self.apiClient = apiClient
        self.organizationIDProvider = organizationIDProvider
    }

    func accountDidChange() {
        purchaseContext = nil
        purchasesEnabled = false
        Task { await processUnfinishedTransactions() }
    }

    func loadProducts(force: Bool = false) async {
        guard force || products.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let context = try await loadPurchaseContext(force: force)
            let configuredProductIDs = [context.productIDs.monthly, context.productIDs.yearly]
            guard Set(configuredProductIDs) == Set([Self.monthlyProductID, Self.yearlyProductID]) else {
                throw StoreKitPurchaseError.productConfigurationMismatch
            }
            let loadedProducts = try await Product.products(for: configuredProductIDs)
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
            let context = try await loadPurchaseContext(force: true)
            let result = try await product.purchase(options: [
                .appAccountToken(context.appAccountToken)
            ])
            switch result {
            case .success(let verificationResult):
                let transaction = try verified(verificationResult)
                if context.purchasesEnabled {
                    let subscription = try await submitToBackend(
                        verificationResult,
                        organizationID: context.organizationID
                    )
                    await transaction.finish()
                    statusMessage = "Personal Plus is active until \(displayDate(subscription.expiresAt))."
                } else {
#if DEBUG
                    await recordLocalTestTransaction(transaction)
                    await transaction.finish()
                    statusMessage = "Local StoreKit test completed. Server purchasing remains disabled, so your Hit n Score plan was not changed."
#else
                    throw StoreKitPurchaseError.serverPurchasesDisabled
#endif
                }
                await refreshCurrentEntitlements()
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
            let context = try await loadPurchaseContext(force: true)
            var restoredOnServer = false
            for await entitlement in Transaction.currentEntitlements {
                guard case .verified(let transaction) = entitlement,
                      [Self.monthlyProductID, Self.yearlyProductID].contains(transaction.productID)
                else {
                    continue
                }
                if context.purchasesEnabled {
                    _ = try await submitToBackend(
                        entitlement,
                        organizationID: context.organizationID
                    )
                    await transaction.finish()
                    restoredOnServer = true
                }
            }
            await refreshCurrentEntitlements()
            if context.purchasesEnabled {
                statusMessage = restoredOnServer
                    ? "Your Personal Plus purchase was restored and verified."
                    : "No active Personal Plus subscription was found."
            } else {
                statusMessage = activeProductIDs.isEmpty
                    ? "No active Personal Plus test subscription was found."
                    : "A local test subscription was found. Server purchasing remains disabled."
            }
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
                    guard let context = try? await self.loadPurchaseContext(force: true) else {
                        self.errorMessage = "Sign in and reconnect to verify the pending App Store transaction."
                        continue
                    }
                    if context.purchasesEnabled {
                        _ = try await self.submitToBackend(
                            update,
                            organizationID: context.organizationID
                        )
                        await transaction.finish()
                    } else {
#if DEBUG
                        await self.recordLocalTestTransaction(transaction)
                        await transaction.finish()
#endif
                    }
                    await self.refreshCurrentEntitlements()
                } catch {
                    self.errorMessage = "Unable to verify the App Store transaction: \(error.localizedDescription)"
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

    private func loadPurchaseContext(force: Bool) async throws -> AppleSubscriptionContext {
        if !force, let purchaseContext {
            return purchaseContext
        }
        guard let apiClient,
              let organizationID = organizationIDProvider?()
        else {
            throw StoreKitPurchaseError.signedInPersonalAccountRequired
        }
        let context = try await apiClient.getAppleSubscriptionContext(
            organizationID: organizationID
        )
        purchaseContext = context
        purchasesEnabled = context.purchasesEnabled
        return context
    }

    private func submitToBackend(
        _ verificationResult: VerificationResult<Transaction>,
        organizationID: Int
    ) async throws -> VerifiedAppleSubscription {
        guard let apiClient else {
            throw StoreKitPurchaseError.signedInPersonalAccountRequired
        }
        let appTransactionResult = try await AppTransaction.shared
        _ = try verified(appTransactionResult)
        return try await apiClient.verifyApplePurchase(
            organizationID: organizationID,
            signedTransaction: verificationResult.jwsRepresentation,
            signedAppTransaction: appTransactionResult.jwsRepresentation
        )
    }

    private func processUnfinishedTransactions() async {
        guard let context = try? await loadPurchaseContext(force: true),
              context.purchasesEnabled
        else {
            return
        }
        for await result in Transaction.unfinished {
            do {
                let transaction = try verified(result)
                guard [Self.monthlyProductID, Self.yearlyProductID].contains(transaction.productID) else {
                    continue
                }
                _ = try await submitToBackend(
                    result,
                    organizationID: context.organizationID
                )
                await transaction.finish()
            } catch {
                errorMessage = "A pending App Store transaction is waiting for server verification: \(error.localizedDescription)"
            }
        }
        await refreshCurrentEntitlements()
    }

    private func displayDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func recordLocalTestTransaction(_ transaction: Transaction) async {
        // Local StoreKit testing deliberately does not change the backend plan.
        // Production must send the signed JWS plus a server-issued appAccountToken
        // to the backend and wait for authoritative entitlement activation here.
        let isActive = transaction.revocationDate == nil
            && !transaction.isUpgraded
            && (transaction.expirationDate.map { $0 > Date() } ?? true)

        if isActive {
            activeProductIDs.insert(transaction.productID)
        } else {
            activeProductIDs.remove(transaction.productID)
        }
    }

    private func productOrder(_ productID: String) -> Int {
        productID == Self.monthlyProductID ? 0 : 1
    }
}

private enum StoreKitPurchaseError: LocalizedError {
    case unverified(Error)
    case productConfigurationMismatch
    case serverPurchasesDisabled
    case signedInPersonalAccountRequired

    var errorDescription: String? {
        switch self {
        case .unverified(let error):
            return "The App Store transaction could not be verified: \(error.localizedDescription)"
        case .productConfigurationMismatch:
            return "The App Store products do not match the products allowed by the server."
        case .serverPurchasesDisabled:
            return "Apple purchases are currently disabled by the server."
        case .signedInPersonalAccountRequired:
            return "Sign in to your personal account before managing a subscription."
        }
    }
}
