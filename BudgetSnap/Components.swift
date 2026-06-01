import SwiftUI
import UIKit

enum BudgetSnapTheme {
    static let background = Color(uiColor: .systemBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
    static let uncheckedStroke = Color(uiColor: .tertiaryLabel)
    static let circularControl = Color(uiColor: .systemGray4)
    static let circularControlIcon = Color(uiColor: .label)
    static let accent = Color(red: 0.46, green: 0.63, blue: 1.0)
    static let glassTint = accent.opacity(0.12)
}

extension View {
    @ViewBuilder
    func budgetGlass(cornerRadius: CGFloat, tint: Color = BudgetSnapTheme.glassTint, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct BudgetGlassContainer<Content: View>: View {
    var spacing: CGFloat = 18
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class SwipeBackViewController: UIViewController, UIGestureRecognizerDelegate {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enableSwipeBack()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableSwipeBack()
        }

        private func enableSwipeBack() {
            guard let navigationController else { return }
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            navigationController?.viewControllers.count ?? 0 > 1
        }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        background(SwipeBackEnabler().frame(width: 0, height: 0))
    }
}

struct CleanIconButton<Label: View>: View {
    var size: CGFloat = 48
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct BudgetSnapTopBar: View {
    let title: String
    let onBack: () -> Void
    let onSelect: () -> Void
    let isSelecting: Bool
    let onShare: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            CleanIconButton(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 31, weight: .medium))
            }

            CleanIconButton(action: onSelect) {
                Image(systemName: isSelecting ? "checkmark.circle" : "pencil.circle")
                    .font(.system(size: 31, weight: .regular))
            }
            .accessibilityLabel(isSelecting ? "Done selecting transactions" : "Select transactions")

            Text(title)
                .font(.title2)
                .foregroundStyle(BudgetSnapTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)

            CleanIconButton(action: onShare) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 29, weight: .regular))
            }
            .disabled(isSelecting)
            .opacity(isSelecting ? 0.35 : 1)
            .accessibilityLabel("Share list with iCloud")

            CleanIconButton(action: onSettings) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 31, weight: .regular))
            }
            .disabled(isSelecting)
            .opacity(isSelecting ? 0.35 : 1)
            .accessibilityLabel("Open list settings")
        }
        .foregroundStyle(BudgetSnapTheme.accent)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(.clear)
    }
}

struct ListsTopBar: View {
    let isEditing: Bool
    let onEdit: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            CleanIconButton(action: onEdit) {
                Image(systemName: isEditing ? "checkmark.circle" : "pencil.circle")
                    .font(.system(size: 31, weight: .regular))
            }
            .accessibilityLabel(isEditing ? "Done editing lists" : "Edit lists")

            Spacer()

            CleanIconButton(action: onSettings) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 31, weight: .regular))
            }
            .accessibilityLabel("Open settings")
        }
        .foregroundStyle(BudgetSnapTheme.accent)
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 2)
        .background(.clear)
    }
}

struct SpendListRow: View {
    let list: SpendList
    let isEditing: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            if isEditing {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(list.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(BudgetSnapTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 12) {
                    Text("\(list.itemCount) items")
                        .font(.title3)
                        .foregroundStyle(BudgetSnapTheme.secondaryText)

                    if list.isShared {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(BudgetSnapTheme.secondaryText)
                    }
                }
            }

            Spacer(minLength: 16)

            Text(list.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.title2.weight(.bold))
                .foregroundStyle(BudgetSnapTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 26)
        .frame(height: 136)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(BudgetSnapTheme.separator)
                .frame(height: 1)
        }
    }
}

struct BudgetSnapTotalHeader: View {
    let title: String
    let total: Decimal
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onNext) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BudgetSnapTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch transaction filter")

            HStack(spacing: 23) {
                CircleArrowButton(systemName: "chevron.left", action: onPrevious)

                Text(total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(BudgetSnapTheme.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                CircleArrowButton(systemName: "chevron.right", action: onNext)
            }

            Capsule()
                .fill(Color(white: 0.55))
                .frame(width: 62, height: 4)
                .padding(.top, 4)
        }
    }
}

struct CircleArrowButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BudgetSnapTheme.circularControlIcon)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(uiColor: .secondarySystemFill))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct ExpandCollapseControls: View {
    let onExpandAll: () -> Void
    let onCollapseAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Expand all", action: onExpandAll)
            Text("|")
                .foregroundStyle(BudgetSnapTheme.secondaryText)
            Button("Collapse all", action: onCollapseAll)
        }
        .font(.title3)
        .foregroundStyle(BudgetSnapTheme.accent)
    }
}

struct BudgetSnapCategorySection: View {
    let section: CategoryTransactionSection
    let isCollapsed: Bool
    let onToggleSection: () -> Void
    let onToggleTransaction: (Transaction.ID) -> Void
    let isSelecting: Bool
    let selectedTransactionIDs: Set<Transaction.ID>
    let onSelectTransaction: (Transaction.ID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleSection) {
                HStack(alignment: .firstTextBaseline) {
                    Text(section.category.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(BudgetSnapTheme.primaryText)

                    Spacer()

                    Text(section.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(BudgetSnapTheme.primaryText)
                        .monospacedDigit()

                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(BudgetSnapTheme.accent)
                        .frame(width: 34)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, isCollapsed ? 0 : 22)
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(section.transactions) { transaction in
                        BudgetSnapTransactionRow(
                            transaction: transaction,
                            category: section.category,
                            isSelecting: isSelecting,
                            isSelected: selectedTransactionIDs.contains(transaction.id),
                            onToggle: { onToggleTransaction(transaction.id) },
                            onSelect: { onSelectTransaction(transaction.id) }
                        )
                    }
                }
            }
        }
    }
}

struct BudgetSnapTransactionRow: View {
    let transaction: Transaction
    let category: BudgetCategory
    let isSelecting: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void

    private var isMarked: Bool {
        isSelecting ? isSelected : transaction.isChecked
    }

    var body: some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(category.tint)
                .frame(width: 10)
                .padding(.vertical, 6)

            Button(action: isSelecting ? onSelect : onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isMarked ? BudgetSnapTheme.accent : BudgetSnapTheme.uncheckedStroke, lineWidth: 3)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isMarked ? BudgetSnapTheme.accent : .clear)
                        }
                        .frame(width: 34, height: 34)

                    if isMarked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(BudgetSnapTheme.background)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)

            Text(transaction.title)
                .font(.title3)
                .foregroundStyle(BudgetSnapTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 12)

            Text(transaction.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.title3)
                .foregroundStyle(BudgetSnapTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(height: 98)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                onSelect()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(BudgetSnapTheme.separator)
                .frame(height: 1)
                .padding(.leading, 78)
        }
    }

    private var accessibilityLabel: String {
        if isSelecting {
            return isSelected ? "Deselect transaction" : "Select transaction"
        }

        return transaction.isChecked ? "Mark unchecked" : "Mark checked"
    }
}

struct TransactionBottomBar: View {
    let sortMode: TransactionSortMode
    let onSort: () -> Void
    let onCalendar: () -> Void
    let onChart: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack {
            CleanIconButton(action: onSort) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 32, weight: .regular))
            }
            .accessibilityLabel("Sort transactions by \(sortMode.label)")

            Spacer()

            CleanIconButton(action: onCalendar) {
                Image(systemName: "calendar")
                    .font(.system(size: 32, weight: .regular))
            }
            .accessibilityLabel("Show transaction calendar")

            Spacer()

            CleanIconButton(action: onChart) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 32, weight: .regular))
            }
            .accessibilityLabel("Show tag spending chart")

            Spacer()

            CleanIconButton(size: 54, action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 42, weight: .regular))
            }
            .accessibilityLabel("Add transaction")
        }
        .foregroundStyle(BudgetSnapTheme.accent)
        .padding(.horizontal, 34)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.clear)
    }
}

struct TransactionSelectionBottomBar: View {
    let selectedCount: Int
    let onMove: () -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            CleanIconButton(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 30, weight: .regular))
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.35 : 1)
            .accessibilityLabel("Delete selected transactions")

            CleanIconButton(action: onMove) {
                Image(systemName: "tag")
                    .font(.system(size: 30, weight: .regular))
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.35 : 1)
            .accessibilityLabel("Move selected transactions")

            Spacer()

            Text("\(selectedCount) selected")
                .font(.headline.weight(.bold))
                .foregroundStyle(BudgetSnapTheme.secondaryText)
                .monospacedDigit()

            Spacer()

            CleanIconButton(action: onDone) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32, weight: .regular))
            }
            .accessibilityLabel("Done selecting")
        }
        .foregroundStyle(BudgetSnapTheme.accent)
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.clear)
    }
}

struct ListsBottomBar: View {
    let sortMode: ListSortMode
    let onSort: () -> Void
    let onTags: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack {
            CleanIconButton(action: onSort) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 32, weight: .regular))
            }
            .accessibilityLabel("Sort lists by \(sortMode.label)")

            Spacer()

            CleanIconButton(action: onTags) {
                Image(systemName: "tag.circle")
                    .font(.system(size: 32, weight: .regular))
            }
            .accessibilityLabel("Manage tags")

            Spacer()

            CleanIconButton(size: 54, action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 42, weight: .regular))
            }
            .accessibilityLabel("Add list")
        }
        .foregroundStyle(BudgetSnapTheme.accent)
        .padding(.horizontal, 34)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.clear)
    }
}

struct BottomIconButton: View {
    let systemName: String

    var body: some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: 32, weight: .regular))
                .frame(width: 48, height: 48)
        }
    }
}
