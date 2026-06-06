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

    func iPadReadableWidth(_ maxWidth: CGFloat = 760) -> some View {
        modifier(IPadReadableWidthModifier(maxWidth: maxWidth))
    }
}

private struct IPadReadableWidthModifier: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }
}

struct CleanIconButton<Label: View>: View {
    var size: CGFloat = 42
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
        .iPadReadableWidth(820)
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
        .iPadReadableWidth()
    }
}

struct SpendListRow: View {
    let list: SpendList
    let isEditing: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if isEditing {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(list.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BudgetSnapTheme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Text("\(list.itemCount) items")
                        .font(.subheadline)
                        .foregroundStyle(BudgetSnapTheme.secondaryText)

                    if list.isShared {
                        Image(systemName: "person.2.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BudgetSnapTheme.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(list.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.headline.weight(.bold))
                .foregroundStyle(BudgetSnapTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .frame(minHeight: 104)
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
    let onDuplicateTransaction: (Transaction.ID) -> Void
    let onDeleteTransaction: (Transaction.ID) -> Void
    let onMoveTransaction: (Transaction.ID) -> Void
    let onOpenTransaction: (Transaction) -> Void
    let isSelecting: Bool
    let selectedTransactionIDs: Set<Transaction.ID>
    let onSelectTransaction: (Transaction.ID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleSection) {
                HStack(alignment: .firstTextBaseline) {
                    Text(section.category.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BudgetSnapTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer()

                    Text(section.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BudgetSnapTheme.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BudgetSnapTheme.accent)
                        .frame(width: 28)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, isCollapsed ? 0 : 12)
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(section.transactions) { transaction in
                        SwipeActionRow(
                            isEnabled: !isSelecting,
                            onDuplicate: { onDuplicateTransaction(transaction.id) },
                            onDelete: { onDeleteTransaction(transaction.id) }
                        ) {
                            BudgetSnapTransactionRow(
                                transaction: transaction,
                                category: section.category,
                                isSelecting: isSelecting,
                                isSelected: selectedTransactionIDs.contains(transaction.id),
                                onToggle: { onToggleTransaction(transaction.id) },
                                onSelect: { onSelectTransaction(transaction.id) },
                                onDuplicate: { onDuplicateTransaction(transaction.id) },
                                onMove: { onMoveTransaction(transaction.id) },
                                onDelete: { onDeleteTransaction(transaction.id) },
                                onOpen: { onOpenTransaction(transaction) }
                            )
                        }
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
    let onDuplicate: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void
    let onOpen: () -> Void

    private var isMarked: Bool {
        isSelecting ? isSelected : transaction.isChecked
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(category.tint)
                .frame(width: 8)
                .padding(.vertical, 4)

            Button(action: isSelecting ? onSelect : onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isMarked ? BudgetSnapTheme.accent : BudgetSnapTheme.uncheckedStroke, lineWidth: 2.5)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isMarked ? BudgetSnapTheme.accent : .clear)
                        }
                        .frame(width: 28, height: 28)

                    if isMarked {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(BudgetSnapTheme.background)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)

            Text(transaction.title)
                .font(.body)
                .foregroundStyle(BudgetSnapTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(transaction.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.body)
                    .foregroundStyle(BudgetSnapTheme.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if transaction.recurrence.isRecurring {
                    Text("recurring")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BudgetSnapTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.leading, 0)
        .padding(.trailing, 22)
        .frame(minHeight: 70)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                onSelect()
            } else {
                onOpen()
            }
        }
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Button {
                onMove()
            } label: {
                Label("Move", systemImage: "tag")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(BudgetSnapTheme.separator)
                .frame(height: 1)
                .padding(.leading, 68)
        }
    }

    private var accessibilityLabel: String {
        if isSelecting {
            return isSelected ? "Deselect transaction" : "Select transaction"
        }

        return transaction.isChecked ? "Mark unchecked" : "Mark checked"
    }
}

struct SwipeActionRow<Content: View>: View {
    var isEnabled = true
    let onDuplicate: (() -> Void)?
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let actionWidth: CGFloat = 84
    private let horizontalStartThreshold: CGFloat = 24
    private let horizontalDominanceRatio: CGFloat = 1.9

    private var currentOffset: CGFloat {
        guard isEnabled else { return 0 }
        let minimumOffset = -actionWidth
        let maximumOffset = onDuplicate == nil ? 0 : actionWidth
        return max(minimumOffset, min(maximumOffset, offset + dragTranslation))
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if let onDuplicate {
                    Button {
                        close()
                        onDuplicate()
                    } label: {
                        Image(systemName: "plus.square.on.square")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: actionWidth)
                            .frame(maxHeight: .infinity)
                            .background(BudgetSnapTheme.accent)
                    }
                    .accessibilityLabel("Duplicate")
                }

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    close()
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(.red)
                }
                .accessibilityLabel("Delete")
            }

            content
                .background(BudgetSnapTheme.background)
                .offset(x: currentOffset)
                .gesture(
                    DragGesture(minimumDistance: 22, coordinateSpace: .local)
                        .updating($dragTranslation) { value, state, _ in
                            guard isEnabled, isHorizontalActionGesture(value) else { return }
                            let translation = offset == 0 ? allowedOpeningTranslation(value.translation.width) : value.translation.width
                            state = translation
                        }
                        .onEnded { value in
                            guard isEnabled else { return }
                            guard isHorizontalActionGesture(value) else {
                                close()
                                return
                            }

                            let predicted = offset + value.predictedEndTranslation.width
                            let nextOffset: CGFloat
                            if predicted < -actionWidth * 0.58 {
                                nextOffset = -actionWidth
                            } else if onDuplicate != nil && predicted > actionWidth * 0.58 {
                                nextOffset = actionWidth
                            } else {
                                nextOffset = 0
                            }

                            withAnimation(.easeOut(duration: 0.28)) {
                                offset = nextOffset
                            }
                        }
                )
                .onChange(of: isEnabled) { _, newValue in
                    if !newValue {
                        close()
                    }
                }
        }
        .clipped()
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.24)) {
            offset = 0
        }
    }

    private func allowedOpeningTranslation(_ width: CGFloat) -> CGFloat {
        if width < 0 {
            return width
        }

        return onDuplicate == nil ? 0 : width
    }

    private func isHorizontalActionGesture(_ value: DragGesture.Value) -> Bool {
        let width = value.translation.width
        let height = value.translation.height
        let isClearHorizontalDrag = abs(width) > max(horizontalStartThreshold, abs(height) * horizontalDominanceRatio)
        let isOpeningLeft = offset == 0 && width < -horizontalStartThreshold
        let isOpeningRight = offset == 0 && onDuplicate != nil && width > horizontalStartThreshold
        let isAdjustingOpenRow = offset != 0
        return isClearHorizontalDrag && (isOpeningLeft || isOpeningRight || isAdjustingOpenRow)
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
                    .font(.title2)
            }
            .accessibilityLabel("Sort transactions by \(sortMode.label)")

            Spacer()

            CleanIconButton(action: onCalendar) {
                Image(systemName: "calendar")
                    .font(.title2)
            }
            .accessibilityLabel("Show transaction calendar")

            Spacer()

            CleanIconButton(action: onChart) {
                Image(systemName: "chart.pie")
                    .font(.title2)
            }
            .accessibilityLabel("Show tag spending chart")

            Spacer()

            CleanIconButton(size: 48, action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
            }
            .accessibilityLabel("Add transaction")
        }
        .foregroundStyle(BudgetSnapTheme.accent)
        .padding(.horizontal, 32)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.clear)
        .iPadReadableWidth(820)
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
                    .font(.title2)
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.35 : 1)
            .accessibilityLabel("Delete selected transactions")

            CleanIconButton(action: onMove) {
                Image(systemName: "tag")
                    .font(.title2)
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.35 : 1)
            .accessibilityLabel("Move selected transactions")

            Spacer()

            Text("\(selectedCount) selected")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BudgetSnapTheme.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            CleanIconButton(action: onDone) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
            }
            .accessibilityLabel("Done selecting")
        }
        .foregroundStyle(BudgetSnapTheme.accent)
        .padding(.horizontal, 26)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.clear)
        .iPadReadableWidth(820)
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
                    .font(.title2)
            }
            .accessibilityLabel("Sort lists by \(sortMode.label)")

            Spacer()

            CleanIconButton(action: onTags) {
                Image(systemName: "tag.circle")
                    .font(.title2)
            }
            .accessibilityLabel("Manage tags")

            Spacer()

            CleanIconButton(size: 48, action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
            }
            .accessibilityLabel("Add list")
        }
        .foregroundStyle(BudgetSnapTheme.accent)
        .padding(.horizontal, 32)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.clear)
        .iPadReadableWidth()
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
