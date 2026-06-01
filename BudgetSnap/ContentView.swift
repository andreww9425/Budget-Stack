import SwiftUI

struct CategoryTransactionSection: Identifiable {
    var id: BudgetCategory.ID { category.id }
    let category: BudgetCategory
    let transactions: [Transaction]

    var total: Decimal {
        transactions.reduce(0) { $0 + $1.amount }
    }
}

struct ContentView: View {
    @ObservedObject var store: BudgetStore
    @State private var activeSheet: HomeSheet?
    @State private var isEditingLists = false
    @State private var sortMode: ListSortMode = .manual

    var body: some View {
        NavigationStack {
            ZStack {
                BudgetSnapTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ListsTopBar(
                        isEditing: isEditingLists,
                        onEdit: {
                            withAnimation(.snappy) {
                                isEditingLists.toggle()
                            }
                        },
                        onSettings: { activeSheet = .settings }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Lists")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(BudgetSnapTheme.primaryText)
                                .padding(.horizontal, 26)
                                .padding(.top, 38)
                                .padding(.bottom, 38)

                            LazyVStack(spacing: 0) {
                                if sortedLists.isEmpty {
                                    ContentUnavailableView(
                                        "No Lists",
                                        systemImage: "list.bullet.rectangle",
                                        description: Text("Tap the plus button to create your first list.")
                                    )
                                    .foregroundStyle(BudgetSnapTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 28)
                                    .padding(.horizontal, 24)
                                } else {
                                    ForEach(sortedLists) { spendList in
                                        NavigationLink {
                                            TransactionListView(list: spendList, store: store)
                                        } label: {
                                            SpendListRow(
                                                list: spendList,
                                                isEditing: isEditingLists,
                                                onDelete: { store.deleteList(spendList) }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                store.deleteList(spendList)
                                            } label: {
                                                Label("Delete List", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 18)
                    }

                    ListsBottomBar(
                        sortMode: sortMode,
                        onSort: {
                            withAnimation(.snappy) {
                                sortMode = sortMode.next
                            }
                        },
                        onTags: { activeSheet = .tags },
                        onAdd: { activeSheet = .addList }
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addList:
                    AddListView { title, total in
                        store.addList(title: title, total: total)
                    }
                case .settings:
                    SettingsView(store: store)
                case .tags:
                    TagManagerView(store: store)
                }
            }
        }
        .tint(BudgetSnapTheme.accent)
        .enableSwipeBack()
    }

    private var sortedLists: [SpendList] {
        let lists = store.displayedSpendLists
        return switch sortMode {
        case .manual:
            lists
        case .name:
            lists.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .total:
            lists.sorted { $0.total > $1.total }
        }
    }
}

enum HomeSheet: Identifiable {
    case addList
    case settings
    case tags

    var id: String {
        switch self {
        case .addList: "addList"
        case .settings: "settings"
        case .tags: "tags"
        }
    }
}

enum ListSortMode: String, CaseIterable {
    case manual
    case name
    case total

    var next: ListSortMode {
        switch self {
        case .manual: .name
        case .name: .total
        case .total: .manual
        }
    }

    var label: String {
        switch self {
        case .manual: "Manual"
        case .name: "Name"
        case .total: "Total"
        }
    }
}

struct TransactionListView: View {
    let list: SpendList
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var activeSheet: TransactionSheet?
    @State private var transactionFilter: TransactionFilter = .unchecked
    @State private var transactionSortMode: TransactionSortMode = .newest
    @State private var collapsedCategoryIDs: Set<BudgetCategory.ID> = []
    @State private var isSelecting = false
    @State private var isShowingQuickAdd = false
    @State private var selectedTransactionIDs: Set<Transaction.ID> = []
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingMoveConfirmation = false

    private var displayedList: SpendList {
        store.displayedList(list)
    }

    private var listTransactions: [Transaction] {
        store.transactions(for: list)
    }

    private var filteredTransactions: [Transaction] {
        sortedTransactions(listTransactions.filter(transactionFilter.includes))
    }

    private var visibleTotal: Decimal {
        filteredTransactions.reduce(0) { $0 + $1.amount }
    }

    private var sections: [CategoryTransactionSection] {
        store.categories.compactMap { category in
            let categoryTransactions = filteredTransactions.filter { $0.categoryID == category.id }
            guard !categoryTransactions.isEmpty else { return nil }
            return CategoryTransactionSection(category: category, transactions: categoryTransactions)
        }
    }

    var body: some View {
        ZStack {
            BudgetSnapTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                BudgetSnapTopBar(
                    title: displayedList.title,
                    onBack: { dismiss() },
                    onSelect: { toggleSelecting() },
                    isSelecting: isSelecting,
                    onShare: {
                        activeSheet = store.isPremiumUnlocked ? .shareList : .premiumPaywall
                    },
                    onSettings: { activeSheet = .listSettings }
                )

                ScrollView {
                    VStack(spacing: 28) {
                        BudgetSnapTotalHeader(
                            title: transactionFilter.title,
                            total: visibleTotal,
                            onPrevious: {
                                withAnimation(.snappy) {
                                    transactionFilter = transactionFilter.previous
                                }
                            },
                            onNext: {
                                withAnimation(.snappy) {
                                    transactionFilter = transactionFilter.next
                                }
                            }
                        )

                        ExpandCollapseControls(
                            onExpandAll: {
                                withAnimation(.snappy) {
                                    collapsedCategoryIDs.removeAll()
                                }
                            },
                            onCollapseAll: {
                                withAnimation(.snappy) {
                                    collapsedCategoryIDs = Set(sections.map(\.id))
                                }
                            }
                        )

                        LazyVStack(spacing: 30) {
                            if sections.isEmpty {
                                ContentUnavailableView(
                                    "No Transactions",
                                    systemImage: "receipt",
                                    description: Text("Tap the plus button to add your first transaction.")
                                )
                                .foregroundStyle(BudgetSnapTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 42)
                            } else {
                                ForEach(sections) { section in
                                    BudgetSnapCategorySection(
                                        section: section,
                                        isCollapsed: collapsedCategoryIDs.contains(section.id),
                                        onToggleSection: {
                                            withAnimation(.snappy) {
                                                toggleCollapsed(section.id)
                                            }
                                        },
                                        onToggleTransaction: { transactionID in
                                            withAnimation(.snappy) {
                                                store.toggleChecked(for: transactionID)
                                            }
                                        },
                                        isSelecting: isSelecting,
                                        selectedTransactionIDs: selectedTransactionIDs,
                                        onSelectTransaction: { transactionID in
                                            withAnimation(.snappy) {
                                                toggleSelected(transactionID)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 92)
                }
            }

            if isShowingQuickAdd {
                QuickAddTransactionPopup(
                    categories: store.categories,
                    onCancel: {
                        withAnimation(.snappy) {
                            isShowingQuickAdd = false
                        }
                    },
                    onSave: { transaction in
                        store.add(transaction, to: list)
                        withAnimation(.snappy) {
                            isShowingQuickAdd = false
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                TransactionSelectionBottomBar(
                    selectedCount: selectedTransactionIDs.count,
                    onMove: { isShowingMoveConfirmation = true },
                    onDelete: { isShowingDeleteConfirmation = true },
                    onDone: { toggleSelecting() }
                )
            } else {
                TransactionBottomBar(
                    sortMode: transactionSortMode,
                    onSort: {
                        withAnimation(.snappy) {
                            transactionSortMode = transactionSortMode.next
                        }
                    },
                    onCalendar: { activeSheet = .calendar },
                    onChart: { activeSheet = .tagChart },
                    onAdd: {
                        _ = store.ensureMiscellaneousTag()
                        withAnimation(.snappy) {
                            isShowingQuickAdd = true
                        }
                    }
                )
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addTransaction:
                AddTransactionView(categories: store.categories) { transaction in
                    store.add(transaction, to: list)
                }
            case .tagChart:
                TagChartView(store: store, list: list)
            case .calendar:
                TransactionCalendarView(transactions: listTransactions, store: store)
            case .shareList:
                ListSharingView(list: displayedList)
            case .listSettings:
                TransactionListSettingsView(list: displayedList, store: store)
            case .premiumPaywall:
                PremiumPaywallView(store: store, dismissAfterUnlock: false) {
                    activeSheet = .shareList
                }
            }
        }
        .confirmationDialog(
            "Move selected transactions",
            isPresented: $isShowingMoveConfirmation,
            titleVisibility: .visible
        ) {
            ForEach(store.categories) { category in
                Button(category.name) {
                    store.moveTransactions(withIDs: selectedTransactionIDs, to: category.id)
                    finishSelecting()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a tag for \(selectedTransactionIDs.count) selected transactions.")
        }
        .confirmationDialog(
            "Delete selected transactions?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectedTransactionIDs.count) Transactions", role: .destructive) {
                store.deleteTransactions(withIDs: selectedTransactionIDs)
                finishSelecting()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func toggleCollapsed(_ id: BudgetCategory.ID) {
        if collapsedCategoryIDs.contains(id) {
            collapsedCategoryIDs.remove(id)
        } else {
            collapsedCategoryIDs.insert(id)
        }
    }

    private func toggleSelecting() {
        isSelecting.toggle()
        if !isSelecting {
            selectedTransactionIDs.removeAll()
        }
    }

    private func finishSelecting() {
        withAnimation(.snappy) {
            isSelecting = false
            selectedTransactionIDs.removeAll()
        }
    }

    private func toggleSelected(_ id: Transaction.ID) {
        if selectedTransactionIDs.contains(id) {
            selectedTransactionIDs.remove(id)
        } else {
            selectedTransactionIDs.insert(id)
        }
    }

    private func sortedTransactions(_ transactions: [Transaction]) -> [Transaction] {
        switch transactionSortMode {
        case .newest:
            transactions.sorted { $0.date > $1.date }
        case .oldest:
            transactions.sorted { $0.date < $1.date }
        case .amountHigh:
            transactions.sorted { $0.amount > $1.amount }
        case .amountLow:
            transactions.sorted { $0.amount < $1.amount }
        case .name:
            transactions.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
}

enum TransactionSortMode: CaseIterable {
    case newest
    case oldest
    case amountHigh
    case amountLow
    case name

    var label: String {
        switch self {
        case .newest: "Newest"
        case .oldest: "Oldest"
        case .amountHigh: "Amount High"
        case .amountLow: "Amount Low"
        case .name: "Name"
        }
    }

    var next: TransactionSortMode {
        switch self {
        case .newest: .oldest
        case .oldest: .amountHigh
        case .amountHigh: .amountLow
        case .amountLow: .name
        case .name: .newest
        }
    }
}

enum TransactionFilter: CaseIterable {
    case unchecked
    case checked
    case all

    var title: String {
        switch self {
        case .unchecked: "Only Unchecked"
        case .checked: "Only Checked"
        case .all: "All Transactions"
        }
    }

    var next: TransactionFilter {
        switch self {
        case .unchecked: .checked
        case .checked: .all
        case .all: .unchecked
        }
    }

    var previous: TransactionFilter {
        switch self {
        case .unchecked: .all
        case .checked: .unchecked
        case .all: .checked
        }
    }

    func includes(_ transaction: Transaction) -> Bool {
        switch self {
        case .unchecked: !transaction.isChecked
        case .checked: transaction.isChecked
        case .all: true
        }
    }
}

enum TransactionSheet: Identifiable {
    case addTransaction
    case tagChart
    case calendar
    case shareList
    case listSettings
    case premiumPaywall

    var id: String {
        switch self {
        case .addTransaction: "addTransaction"
        case .tagChart: "tagChart"
        case .calendar: "calendar"
        case .shareList: "shareList"
        case .listSettings: "listSettings"
        case .premiumPaywall: "premiumPaywall"
        }
    }
}

struct TransactionCalendarView: View {
    let transactions: [Transaction]
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    private var groupedDays: [TransactionDay] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        return grouped
            .map { date, transactions in
                TransactionDay(
                    date: date,
                    transactions: transactions.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedDays) { day in
                    Section {
                        ForEach(day.transactions) { transaction in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(store.category(for: transaction.categoryID).tint)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(transaction.title)
                                        .font(.body.weight(.semibold))
                                    Text(store.category(for: transaction.categoryID).name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(transaction.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    .monospacedDigit()
                            }
                        }
                    } header: {
                        Text(day.date.formatted(date: .abbreviated, time: .omitted))
                    } footer: {
                        Text(day.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TransactionDay: Identifiable {
    var id: Date { date }
    let date: Date
    let transactions: [Transaction]

    var total: Decimal {
        transactions.reduce(0) { $0 + $1.amount }
    }
}

struct ListSharingView: View {
    let list: SpendList
    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        "\(list.title): \(list.itemCount) items totaling \(list.total.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("iCloud Sharing") {
                    Label("Share this list with someone via iCloud.", systemImage: "person.2.fill")
                    ShareLink(item: shareText) {
                        Label("Send Invite", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Text("Collaborative iCloud syncing will use this entry point once the app has an iCloud data store.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Share List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TransactionListSettingsView: View {
    let list: SpendList
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("List") {
                    LabeledContent("Name", value: list.title)
                    LabeledContent("Items", value: "\(list.itemCount)")
                    LabeledContent(
                        "Total",
                        value: list.total.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                    )
                }

                Section("Transactions") {
                    let transactions = store.transactions(for: list)
                    LabeledContent("Unchecked", value: "\(transactions.filter { !$0.isChecked }.count)")
                    LabeledContent("Checked", value: "\(transactions.filter { $0.isChecked }.count)")
                }
            }
            .navigationTitle("List Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StaticListDetailView: View {
    let list: SpendList
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BudgetSnapTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 18) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 31, weight: .medium))
                    }

                    Text(list.title)
                        .font(.title2)
                        .foregroundStyle(BudgetSnapTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()
                }
                .foregroundStyle(BudgetSnapTheme.accent)
                .padding(.horizontal, 22)
                .padding(.top, 16)

                VStack(spacing: 14) {
                    Text(list.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(BudgetSnapTheme.primaryText)
                        .monospacedDigit()

                    Text("\(list.itemCount) items")
                        .font(.title3)
                        .foregroundStyle(BudgetSnapTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: BudgetStore())
            .previewDisplayName("System")

        ContentView(store: BudgetStore())
            .preferredColorScheme(.light)
            .previewDisplayName("Light")

        ContentView(store: BudgetStore())
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark")
    }
}
