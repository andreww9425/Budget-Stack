import SwiftUI

struct AddTransactionView: View {
    let categories: [BudgetCategory]
    let onSave: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var merchant = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var categoryID: BudgetCategory.ID

    init(categories: [BudgetCategory], onSave: @escaping (Transaction) -> Void) {
        self.categories = categories
        self.onSave = onSave
        _categoryID = State(initialValue: categories.first?.id ?? UUID())
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.filter { "0123456789.".contains($0) })
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedAmount != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    TextField("Name", text: $title)
                    TextField("Merchant", text: $merchant)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Tag") {
                    Picker("Tag", selection: $categoryID) {
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.icon)
                                .tag(category.id)
                        }
                    }
                }
            }
            .navigationTitle("Add Spend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let parsedAmount else { return }
                        onSave(
                            Transaction(
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                                amount: parsedAmount,
                                date: date,
                                categoryID: categoryID
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

struct AddTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        AddTransactionView(categories: BudgetCategory.sample) { _ in }
    }
}

struct QuickAddTransactionPopup: View {
    let categories: [BudgetCategory]
    let onCancel: () -> Void
    let onSave: (Transaction) -> Void

    @State private var itemName = ""
    @State private var cost = ""
    @State private var selectedCategoryID: BudgetCategory.ID?
    @State private var isShowingTagBar = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case itemName
        case cost
    }

    private var parsedCost: Decimal? {
        Decimal(string: cost.filter { "0123456789.".contains($0) })
    }

    private var canSave: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedCost != nil
    }

    private var selectedCategory: BudgetCategory? {
        guard let selectedCategoryID else { return nil }
        return categories.first { $0.id == selectedCategoryID }
    }

    private var fallbackCategory: BudgetCategory? {
        categories.first { $0.id == BudgetCategory.miscellaneousID || $0.name == BudgetCategory.miscellaneous.name } ?? categories.first
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    TextField("Item Name...", text: $itemName)
                        .font(.title2.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .itemName)
                        .onSubmit {
                            focusedField = .cost
                        }
                        .padding(.horizontal, 24)
                        .frame(height: 76)

                    Divider()

                    TextField("$0.00", text: $cost)
                        .font(.title2.weight(.semibold))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .cost)
                        .padding(.horizontal, 24)
                        .frame(height: 76)
                }
                .budgetGlass(cornerRadius: 24, tint: .white.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
                .padding(.horizontal, 20)

                Spacer()
            }

            VStack(spacing: 0) {
                Spacer()

                if isShowingTagBar {
                    QuickAddTagPickerBar(
                        categories: categories,
                        selectedCategoryID: selectedCategoryID,
                        onSelect: { categoryID in
                            withAnimation(.snappy) {
                                selectedCategoryID = categoryID
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) {
                            isShowingTagBar.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "tag.circle")
                                .font(.system(size: 28, weight: .regular))

                            if let selectedCategory {
                                Circle()
                                    .fill(selectedCategory.tint)
                                    .frame(width: 10, height: 10)

                                Text(selectedCategory.name)
                                    .font(.body.weight(.semibold))
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(BudgetSnapTheme.accent)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: 210, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 12)

                    Button {
                        save()
                    } label: {
                        Text("Add")
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(width: 70, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .fixedSize()
                    .disabled(!canSave)
                }
                .frame(height: 64)
                .padding(.horizontal, 16)
                .background(Color(uiColor: .systemBackground))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(uiColor: .separator).opacity(0.35))
                        .frame(height: 1)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear {
            focusedField = .itemName
            selectedCategoryID = fallbackCategory?.id
        }
    }

    private func save() {
        guard let parsedCost, let categoryID = selectedCategoryID ?? fallbackCategory?.id else { return }
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)

        onSave(
            Transaction(
                title: trimmedName,
                merchant: trimmedName,
                amount: parsedCost,
                date: .now,
                categoryID: categoryID
            )
        )
    }
}

struct QuickAddTagPickerBar: View {
    let categories: [BudgetCategory]
    let selectedCategoryID: BudgetCategory.ID?
    let onSelect: (BudgetCategory.ID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories) { category in
                    QuickAddTagChip(
                        category: category,
                        isSelected: selectedCategoryID == category.id
                    ) {
                        onSelect(category.id)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(height: 58)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.25))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.35))
                .frame(height: 1)
        }
    }
}

struct QuickAddTagChip: View {
    let category: BudgetCategory
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                Circle()
                    .fill(category.tint)
                    .frame(width: 22, height: 22)

                Text(category.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(category.tint.opacity(0.16))
                }
            }
            .overlay {
                if isSelected {
                    Capsule(style: .continuous)
                        .strokeBorder(category.tint.opacity(0.45), lineWidth: 1)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
