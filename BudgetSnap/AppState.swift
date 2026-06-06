import Foundation
import Combine
import UIKit
import StoreKit

enum ICloudSyncState: Equatable {
    case checking
    case syncing
    case available
    case unavailable
    case failed
}

struct ICloudSyncStatus: Equatable {
    var state: ICloudSyncState = .checking
    var summary = "Checking iCloud..."
    var detail: String?
    var lastCheckedAt: Date?
    var lastFetchedAt: Date?
    var lastPushedAt: Date?

    var isBusy: Bool {
        state == .checking || state == .syncing
    }
}

struct BudgetRecoverySnapshot: Codable {
    var savedAt: Date
    var reason: String
    var snapshot: BudgetCloudSnapshot
}

final class BudgetStore: ObservableObject {
    @Published var categories: [BudgetCategory] {
        didSet { saveCategories() }
    }
    @Published var transactions: [Transaction] {
        didSet { save() }
    }
    @Published var spendLists: [SpendList] {
        didSet { saveLists() }
    }
    @Published var selectedAppIcon: AppIconChoice {
        didSet { saveSettings() }
    }
    @Published var selectedAppIconAppearance: AppIconAppearance {
        didSet { saveSettings() }
    }
    @Published var isPremiumUnlocked: Bool {
        didSet { saveSettings() }
    }
    @Published private(set) var iCloudSyncStatus = ICloudSyncStatus()

    private let storageKey = "budgetsnap.transactions"
    private let categoriesStorageKey = "budgetsnap.categories"
    private let listsStorageKey = "budgetsnap.lists"
    private let appIconStorageKey = "budgetsnap.appIcon"
    private let appIconAppearanceStorageKey = "budgetsnap.appIconAppearance"
    private let premiumStorageKey = "budgetsnap.premiumUnlocked"
    private let localModifiedStorageKey = "budgetstack.localModifiedAt"
    private let localRecoverySnapshotsStorageKey = "budgetstack.localRecoverySnapshots"
    private let maxLocalRecoverySnapshots = 8
    private let iCloudSync = ICloudSyncStore()
    private var isApplyingCloudSnapshot = false
    private var foregroundObserver: NSObjectProtocol?
    private var pendingCloudSave: DispatchWorkItem?
    private static let removedDefaultListIDs = Set([
        SpendList.appleCardID,
        SpendList.appleSavingsID,
        SpendList.awWantListID,
        SpendList.newHomeID,
        SpendList.lowesCardID
    ])

    init() {
        let loadedCategories: [BudgetCategory]
        if let data = UserDefaults.standard.data(forKey: categoriesStorageKey),
           let decoded = try? JSONDecoder().decode([BudgetCategory].self, from: data),
           !decoded.isEmpty {
            loadedCategories = decoded
        } else {
            loadedCategories = BudgetCategory.sample
        }

        let loadedTransactions: [Transaction]
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data),
           decoded.allSatisfy({ transaction in loadedCategories.contains { $0.id == transaction.categoryID } }) {
            loadedTransactions = decoded.filter { Self.removedDefaultListIDs.contains($0.listID) == false }
        } else {
            loadedTransactions = []
        }

        let loadedLists: [SpendList]
        if let data = UserDefaults.standard.data(forKey: listsStorageKey),
           let decoded = try? JSONDecoder().decode([SpendList].self, from: data) {
            loadedLists = decoded.filter { Self.removedDefaultListIDs.contains($0.id) == false }
        } else {
            loadedLists = []
        }

        let loadedIcon: AppIconChoice
        if let rawValue = UserDefaults.standard.string(forKey: appIconStorageKey),
           let decoded = AppIconChoice(rawValue: rawValue) {
            loadedIcon = decoded
        } else {
            loadedIcon = .blue
        }

        let loadedIconAppearance: AppIconAppearance
        if let rawValue = UserDefaults.standard.string(forKey: appIconAppearanceStorageKey),
           let decoded = AppIconAppearance(rawValue: rawValue) {
            loadedIconAppearance = decoded
        } else {
            loadedIconAppearance = .regular
        }

        categories = loadedCategories
        transactions = loadedTransactions
        spendLists = loadedLists
        selectedAppIcon = loadedIcon
        selectedAppIconAppearance = loadedIconAppearance
        isPremiumUnlocked = UserDefaults.standard.bool(forKey: premiumStorageKey)

        configureICloudSync()
        Task {
            await refreshPremiumEntitlement()
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        pendingCloudSave?.cancel()
    }

    var summaries: [SpendingSummary] {
        summaries(for: nil)
    }

    func summaries(for list: SpendList?) -> [SpendingSummary] {
        categories.map { category in
            let spent = transactions(for: list)
                .filter { $0.categoryID == category.id }
                .reduce(Decimal(0)) { $0 + $1.amount }

            return SpendingSummary(category: category, spent: spent)
        }
    }

    var tagSummaries: [SpendingSummary] {
        summaries
            .filter { $0.spent > 0 }
            .sorted { $0.spent > $1.spent }
    }

    var recentTransactions: [Transaction] {
        transactions.sorted { $0.date > $1.date }
    }

    var monthTotal: Decimal {
        transactions.reduce(0) { $0 + $1.amount }
    }

    var monthlyLimit: Decimal {
        categories.reduce(0) { $0 + $1.monthlyLimit }
    }

    var displayedSpendLists: [SpendList] {
        spendLists.map(displayedList)
    }

    func displayedList(_ list: SpendList) -> SpendList {
        var updatedList = list
        let listTransactions = transactions(for: list)
        updatedList.itemCount = listTransactions.count
        updatedList.total = listTransactions.reduce(0) { $0 + $1.amount }
        return updatedList
    }

    func transactions(for list: SpendList?) -> [Transaction] {
        guard let list else { return transactions }
        return transactions.filter { $0.listID == list.id }
    }

    func add(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
    }

    func add(_ transaction: Transaction, to list: SpendList) {
        var updatedTransaction = transaction
        updatedTransaction.listID = list.id
        add(updatedTransaction)
    }

    func duplicateTransaction(withID id: Transaction.ID) {
        guard let transaction = transactions.first(where: { $0.id == id }) else { return }

        let duplicate = Transaction(
            listID: transaction.listID,
            title: transaction.title,
            merchant: transaction.merchant,
            amount: transaction.amount,
            date: Date(),
            categoryID: transaction.categoryID,
            isChecked: transaction.isChecked,
            recurrence: transaction.recurrence,
            privateNote: transaction.privateNote
        )

        if let originalIndex = transactions.firstIndex(where: { $0.id == id }) {
            transactions.insert(duplicate, at: originalIndex)
        } else {
            add(duplicate)
        }
    }

    func updateTransaction(_ transaction: Transaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        transactions[index] = transaction
    }

    func deleteTransactions(withIDs ids: Set<Transaction.ID>) {
        guard !ids.isEmpty else { return }
        saveLocalRecoverySnapshot(reason: "Before deleting transactions")
        transactions.removeAll { ids.contains($0.id) }
    }

    func moveTransactions(withIDs ids: Set<Transaction.ID>, to categoryID: BudgetCategory.ID) {
        guard !ids.isEmpty else { return }
        for index in transactions.indices where ids.contains(transactions[index].id) {
            transactions[index].categoryID = categoryID
        }
    }

    func addList(title: String, total: Decimal, itemCount: Int = 0) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        spendLists.append(SpendList(title: trimmedTitle, itemCount: itemCount, total: total))
    }

    func deleteList(_ list: SpendList) {
        saveLocalRecoverySnapshot(reason: "Before deleting list")
        spendLists.removeAll { $0.id == list.id }
        transactions.removeAll { $0.listID == list.id }
    }

    func addTag(name: String, icon: String, colorName: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        categories.append(
            BudgetCategory(
                name: trimmedName,
                icon: icon,
                colorName: colorName,
                monthlyLimit: 0
            )
        )
    }

    func ensureMiscellaneousTag() -> BudgetCategory {
        if let existing = categories.first(where: { $0.id == BudgetCategory.miscellaneousID || $0.name == BudgetCategory.miscellaneous.name }) {
            return existing
        }

        let miscellaneous = BudgetCategory.miscellaneous
        categories.append(miscellaneous)
        return miscellaneous
    }

    func deleteTag(_ tag: BudgetCategory) {
        guard categories.count > 1 else { return }
        guard transactions.contains(where: { $0.categoryID == tag.id }) == false else { return }
        saveLocalRecoverySnapshot(reason: "Before deleting tag")
        categories.removeAll { $0.id == tag.id }
    }

    func selectAppIcon(_ choice: AppIconChoice) {
        selectedAppIcon = choice
    }

    func selectAppIcon(_ choice: AppIconChoice, appearance: AppIconAppearance) {
        selectedAppIcon = choice
        selectedAppIconAppearance = appearance
    }

    func unlockPremium() {
        setPremiumUnlocked(true)
    }

    func setPremiumUnlocked(_ isUnlocked: Bool) {
        isPremiumUnlocked = isUnlocked
    }

    @MainActor
    func refreshPremiumEntitlement() async {
        var hasPremium = false

        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == PremiumPurchaseManager.productID {
                hasPremium = true
                break
            }
        }

        setPremiumUnlocked(hasPremium)
    }

    func toggleChecked(for transactionID: Transaction.ID) {
        guard let index = transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        transactions[index].isChecked.toggle()
    }

    func category(for id: BudgetCategory.ID) -> BudgetCategory {
        categories.first { $0.id == id } ?? categories[0]
    }

    var iCloudLastLocalChangeDate: Date? {
        hasLocalModifiedDate ? localModifiedAt : nil
    }

    var localRecoverySnapshotCount: Int {
        localRecoverySnapshots.count
    }

    var lastLocalRecoverySnapshotDate: Date? {
        localRecoverySnapshots.first?.savedAt
    }

    func refreshICloudSync() {
        checkICloudAndReconcile(isManual: true)
    }

    func pushCurrentDataToICloud() {
        syncBudgetDataToICloud(isManual: true)
    }

    func restoreMostRecentLocalBackup() {
        guard let recoverySnapshot = localRecoverySnapshots.first else {
            iCloudSyncStatus.state = .failed
            iCloudSyncStatus.summary = "No backup found"
            iCloudSyncStatus.detail = "Budget Stack has not made a local recovery snapshot yet."
            return
        }

        saveLocalRecoverySnapshot(reason: "Before restoring local backup")
        pendingCloudSave?.cancel()
        isApplyingCloudSnapshot = true
        categories = recoverySnapshot.snapshot.categories.isEmpty ? BudgetCategory.sample : recoverySnapshot.snapshot.categories
        spendLists = recoverySnapshot.snapshot.spendLists.filter { Self.removedDefaultListIDs.contains($0.id) == false }
        transactions = validTransactions(from: recoverySnapshot.snapshot.transactions, categories: categories, spendLists: spendLists)
        isApplyingCloudSnapshot = false
        localModifiedAt = Date()

        iCloudSyncStatus.summary = "Restored local backup"
        iCloudSyncStatus.detail = "Budget Stack restored your most recent recovery snapshot and is pushing it to iCloud."
        syncBudgetDataToICloud(isManual: true)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        syncBudgetDataToICloud()
    }

    private func saveLists() {
        guard let data = try? JSONEncoder().encode(spendLists) else { return }
        UserDefaults.standard.set(data, forKey: listsStorageKey)
        syncBudgetDataToICloud()
    }

    private func saveCategories() {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        UserDefaults.standard.set(data, forKey: categoriesStorageKey)
        syncBudgetDataToICloud()
    }

    private func saveSettings() {
        UserDefaults.standard.set(selectedAppIcon.rawValue, forKey: appIconStorageKey)
        UserDefaults.standard.set(selectedAppIconAppearance.rawValue, forKey: appIconAppearanceStorageKey)
        UserDefaults.standard.set(isPremiumUnlocked, forKey: premiumStorageKey)
    }

    private func configureICloudSync() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkICloudAndReconcile()
        }

        checkICloudAndReconcile()
    }

    private func checkICloudAndReconcile(isManual: Bool = false) {
        iCloudSyncStatus.state = .checking
        iCloudSyncStatus.summary = "Checking iCloud..."
        iCloudSyncStatus.detail = nil
        iCloudSyncStatus.lastCheckedAt = Date()

        iCloudSync.accountState { [weak self] accountState in
            guard let self else { return }

            switch accountState {
            case .available:
                self.reconcileWithICloud(isManual: isManual)
            case .unavailable(let message):
                self.iCloudSyncStatus.state = .unavailable
                self.iCloudSyncStatus.summary = "iCloud unavailable"
                self.iCloudSyncStatus.detail = message
            }
        }
    }

    private func reconcileWithICloud(isManual: Bool = false) {
        iCloudSyncStatus.state = .syncing
        iCloudSyncStatus.summary = isManual ? "Refreshing from iCloud..." : "Syncing with iCloud..."
        iCloudSyncStatus.detail = nil

        iCloudSync.loadSnapshot { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let cloudSnapshot):
                self.handleLoadedCloudSnapshot(cloudSnapshot, isManual: isManual)
            case .failure(let error):
                self.iCloudSyncStatus.state = .failed
                self.iCloudSyncStatus.summary = "Sync check failed"
                self.iCloudSyncStatus.detail = error.localizedDescription
            }
        }
    }

    private func handleLoadedCloudSnapshot(_ cloudSnapshot: BudgetCloudSnapshot?, isManual: Bool) {
        guard let cloudSnapshot else {
            if hasLocalBudgetData {
                iCloudSyncStatus.summary = "No iCloud copy found"
                iCloudSyncStatus.detail = "Uploading this device's current data."
                syncBudgetDataToICloud(isManual: isManual)
            } else {
                iCloudSyncStatus.state = .available
                iCloudSyncStatus.summary = "iCloud ready"
                iCloudSyncStatus.detail = "No budget data has been synced yet."
            }
            return
        }

        iCloudSyncStatus.lastFetchedAt = Date()

        if shouldKeepLocalDataInsteadOfEmptyCloud(cloudSnapshot) {
            iCloudSyncStatus.state = .failed
            iCloudSyncStatus.summary = "Empty iCloud data blocked"
            iCloudSyncStatus.detail = "This device has budget data, but iCloud returned an empty copy. Budget Stack kept your local data and did not overwrite it."
            return
        }

        if shouldMergeFirstSync(with: cloudSnapshot) {
            let mergedSnapshot = mergedSnapshot(with: cloudSnapshot)
            applyCloudSnapshot(mergedSnapshot)
            iCloudSyncStatus.summary = "Merged iCloud data"
            iCloudSyncStatus.detail = "This device and iCloud both had data, so Budget Stack merged them."
            syncBudgetDataToICloud(isManual: isManual)
        } else if cloudSnapshot.updatedAt > localModifiedAt {
            applyCloudSnapshot(cloudSnapshot)
            iCloudSyncStatus.state = .available
            iCloudSyncStatus.summary = "Updated from iCloud"
            iCloudSyncStatus.detail = "Fetched the latest budget data from iCloud."
        } else if hasLocalBudgetData {
            if isManual {
                iCloudSyncStatus.state = .available
                iCloudSyncStatus.summary = "Already up to date"
                iCloudSyncStatus.detail = "This device has the latest budget data."
            } else {
                syncBudgetDataToICloud()
            }
        } else {
            iCloudSyncStatus.state = .available
            iCloudSyncStatus.summary = "iCloud ready"
            iCloudSyncStatus.detail = "No budget data has been synced yet."
        }
    }

    private func syncBudgetDataToICloud(isManual: Bool = false) {
        guard !isApplyingCloudSnapshot else { return }

        if isManual && !hasLocalBudgetData {
            iCloudSyncStatus.state = .available
            iCloudSyncStatus.summary = "Nothing to upload"
            iCloudSyncStatus.detail = "Create a list or transaction before pushing data to iCloud."
            return
        }

        let now = Date()
        localModifiedAt = now

        let snapshot = BudgetCloudSnapshot(
            updatedAt: now,
            categories: categories,
            transactions: transactions,
            spendLists: spendLists
        )

        iCloudSyncStatus.state = .syncing
        iCloudSyncStatus.summary = isManual ? "Pushing current data..." : "Syncing changes..."
        iCloudSyncStatus.detail = nil

        pendingCloudSave?.cancel()
        let saveWork = DispatchWorkItem { [weak self, iCloudSync] in
            iCloudSync.save(snapshot) { result in
                guard let self else { return }

                switch result {
                case .success:
                    self.iCloudSyncStatus.state = .available
                    self.iCloudSyncStatus.summary = "iCloud sync active"
                    self.iCloudSyncStatus.detail = "Your lists, tags, and transactions are synced through your iCloud account."
                    self.iCloudSyncStatus.lastPushedAt = Date()
                case .failure(let error):
                    self.iCloudSyncStatus.state = .failed
                    self.iCloudSyncStatus.summary = "Sync upload failed"
                    self.iCloudSyncStatus.detail = error.localizedDescription
                }
            }
        }
        pendingCloudSave = saveWork

        if isManual {
            DispatchQueue.main.async(execute: saveWork)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: saveWork)
        }
    }

    private func applyCloudSnapshot(_ snapshot: BudgetCloudSnapshot) {
        saveLocalRecoverySnapshot(reason: "Before applying iCloud data")
        pendingCloudSave?.cancel()
        isApplyingCloudSnapshot = true
        categories = snapshot.categories.isEmpty ? BudgetCategory.sample : snapshot.categories
        spendLists = snapshot.spendLists.filter { Self.removedDefaultListIDs.contains($0.id) == false }
        transactions = validTransactions(from: snapshot.transactions, categories: categories, spendLists: spendLists)
        isApplyingCloudSnapshot = false
        localModifiedAt = snapshot.updatedAt
    }

    private var hasLocalBudgetData: Bool {
        !spendLists.isEmpty || !transactions.isEmpty || categories != BudgetCategory.sample
    }

    private func shouldKeepLocalDataInsteadOfEmptyCloud(_ cloudSnapshot: BudgetCloudSnapshot) -> Bool {
        hasLocalBudgetData && !cloudSnapshot.hasUserData
    }

    private var localModifiedAt: Date {
        get {
            UserDefaults.standard.object(forKey: localModifiedStorageKey) as? Date ?? .distantPast
        }
        set {
            UserDefaults.standard.set(newValue, forKey: localModifiedStorageKey)
        }
    }

    private var hasLocalModifiedDate: Bool {
        UserDefaults.standard.object(forKey: localModifiedStorageKey) != nil
    }

    private func shouldMergeFirstSync(with cloudSnapshot: BudgetCloudSnapshot) -> Bool {
        hasLocalBudgetData && !hasLocalModifiedDate && !cloudSnapshot.spendLists.isEmpty
    }

    private func mergedSnapshot(with cloudSnapshot: BudgetCloudSnapshot) -> BudgetCloudSnapshot {
        var mergedCategories: [BudgetCategory.ID: BudgetCategory] = [:]
        cloudSnapshot.categories.forEach { mergedCategories[$0.id] = $0 }
        categories.forEach { mergedCategories[$0.id] = $0 }

        var mergedLists: [SpendList.ID: SpendList] = [:]
        cloudSnapshot.spendLists.forEach { mergedLists[$0.id] = $0 }
        spendLists.forEach { mergedLists[$0.id] = $0 }

        var mergedTransactions: [Transaction.ID: Transaction] = [:]
        cloudSnapshot.transactions.forEach { mergedTransactions[$0.id] = $0 }
        transactions.forEach { mergedTransactions[$0.id] = $0 }

        let categories = Array(mergedCategories.values)
        let spendLists = Array(mergedLists.values)

        return BudgetCloudSnapshot(
            updatedAt: Date(),
            categories: categories,
            transactions: validTransactions(
                from: Array(mergedTransactions.values),
                categories: categories,
                spendLists: spendLists
            ),
            spendLists: spendLists
        )
    }

    private func validTransactions(
        from transactions: [Transaction],
        categories: [BudgetCategory],
        spendLists: [SpendList]
    ) -> [Transaction] {
        let categoryIDs = Set(categories.map(\.id))
        let listIDs = Set(spendLists.map(\.id))

        return transactions.filter { transaction in
            categoryIDs.contains(transaction.categoryID)
                && listIDs.contains(transaction.listID)
                && Self.removedDefaultListIDs.contains(transaction.listID) == false
        }
    }

    private func currentBudgetSnapshot() -> BudgetCloudSnapshot {
        BudgetCloudSnapshot(
            updatedAt: localModifiedAt,
            categories: categories,
            transactions: transactions,
            spendLists: spendLists
        )
    }

    private func saveLocalRecoverySnapshot(reason: String) {
        let snapshot = currentBudgetSnapshot()
        guard snapshot.hasUserData else { return }

        var snapshots = localRecoverySnapshots
        snapshots.insert(
            BudgetRecoverySnapshot(
                savedAt: Date(),
                reason: reason,
                snapshot: snapshot
            ),
            at: 0
        )

        if snapshots.count > maxLocalRecoverySnapshots {
            snapshots = Array(snapshots.prefix(maxLocalRecoverySnapshots))
        }

        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: localRecoverySnapshotsStorageKey)
    }

    private var localRecoverySnapshots: [BudgetRecoverySnapshot] {
        guard let data = UserDefaults.standard.data(forKey: localRecoverySnapshotsStorageKey),
              let snapshots = try? JSONDecoder().decode([BudgetRecoverySnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }
}
