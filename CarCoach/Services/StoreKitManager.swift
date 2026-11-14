import Foundation
import Observation
import StoreKit

@Observable
final class StoreKitManager {
    static let monthlyProductID = "com.dora.carcoach.premium.monthly"
    static let yearlyProductID = "com.dora.carcoach.premium.yearly"
    static let lifetimeProductID = "com.dora.carcoach.premium.lifetime"

    static let allProductIDs: [String] = [
        monthlyProductID,
        yearlyProductID,
        lifetimeProductID
    ]

    private static let debugPreviewDefaultsKey = "carcoach.storekit.debugPreviewUnlocked"

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading: Bool = false
    private(set) var statusMessage: String?

    var debugPreviewUnlocked: Bool {
        didSet {
            UserDefaults.standard.set(debugPreviewUnlocked, forKey: Self.debugPreviewDefaultsKey)
        }
    }

    var isPremium: Bool {
        true
    }

    @ObservationIgnored
    private let updateObserverBox = TransactionObserverBox()

    init() {
        self.debugPreviewUnlocked = true
        UserDefaults.standard.set(true, forKey: Self.debugPreviewDefaultsKey)
        startObservingTransactions()
    }

    deinit {
        updateObserverBox.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            let orderMap = Dictionary(uniqueKeysWithValues: Self.allProductIDs.enumerated().map { ($0.element, $0.offset) })
            self.products = fetched.sorted {
                (orderMap[$0.id] ?? 99) < (orderMap[$1.id] ?? 99)
            }
            await refreshPurchasedEntitlements()
            self.statusMessage = nil
        } catch {
            self.statusMessage = nil
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshPurchasedEntitlements()
                statusMessage = "Đã kích hoạt \(product.displayName) thành công."
                return true
            case .userCancelled:
                statusMessage = "Bạn đã hủy giao dịch."
                return false
            case .pending:
                statusMessage = "Giao dịch đang chờ phê duyệt."
                return false
            @unknown default:
                statusMessage = "Trạng thái giao dịch chưa xác định."
                return false
            }
        } catch {
            statusMessage = "Thanh toán không thành công: \(error.localizedDescription)"
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshPurchasedEntitlements()
            if purchasedProductIDs.isEmpty {
                statusMessage = "Không tìm thấy giao dịch Premium nào trước đây trên tài khoản này."
            } else {
                statusMessage = "Đã khôi phục quyền lợi CarCoach Premium."
            }
        } catch {
            statusMessage = "Không thể khôi phục giao dịch: \(error.localizedDescription)"
        }
    }

    func toggleDebugPreviewUnlock() {
        debugPreviewUnlocked.toggle()
        statusMessage = debugPreviewUnlocked
            ? "Đã bật chế độ Xem trước Premium (Simulator)."
            : "Đã tắt chế độ Xem trước Premium."
    }

    func refreshPurchasedEntitlements() async {
        var activeIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil,
               Self.allProductIDs.contains(transaction.productID) {
                activeIDs.insert(transaction.productID)
            }
        }
        purchasedProductIDs = activeIDs
    }

    private func startObservingTransactions() {
        updateObserverBox.replace(with: Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshPurchasedEntitlements()
                }
            }
        })
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signed):
            return signed
        }
    }
}

private nonisolated final class TransactionObserverBox: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private let lock = NSLock()

    func replace(with newTask: Task<Void, Never>) {
        lock.lock()
        task?.cancel()
        task = newTask
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        task?.cancel()
        task = nil
        lock.unlock()
    }
}
