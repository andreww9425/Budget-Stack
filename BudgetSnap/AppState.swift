import Foundation
import Combine

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

    private let storageKey = "budgetsnap.transactions"
    private let categoriesStorageKey = "budgetsnap.categories"
    private let listsStorageKey = "budgetsnap.lists"
    private let appIconStorageKey = "budgetsnap.appIcon"
    private let appIconAppearanceStorageKey = "budgetsnap.appIconAppearance"
    private let premiumStorageKey = "budgetsnap.premiumUnlocked"
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

    func deleteTransactions(withIDs ids: Set<Transaction.ID>) {
        guard !ids.isEmpty else { return }
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
        spendLists.removeAll { $0.id == list.id }
        transactions.removeAll { $0.listID == list.id }
    }

    func addTag(name: String, colorName: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        categories.append(
            BudgetCategory(
                name: trimmedName,
                icon: "tag.fill",
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
        isPremiumUnlocked = true
    }

    func toggleChecked(for transactionID: Transaction.ID) {
        guard let index = transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        transactions[index].isChecked.toggle()
    }

    func category(for id: BudgetCategory.ID) -> BudgetCategory {
        categories.first { $0.id == id } ?? categories[0]
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func saveLists() {
        guard let data = try? JSONEncoder().encode(spendLists) else { return }
        UserDefaults.standard.set(data, forKey: listsStorageKey)
    }

    private func saveCategories() {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        UserDefaults.standard.set(data, forKey: categoriesStorageKey)
    }

    private func saveSettings() {
        UserDefaults.standard.set(selectedAppIcon.rawValue, forKey: appIconStorageKey)
        UserDefaults.standard.set(selectedAppIconAppearance.rawValue, forKey: appIconAppearanceStorageKey)
        UserDefaults.standard.set(isPremiumUnlocked, forKey: premiumStorageKey)
    }
}
