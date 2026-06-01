import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingList = false
    @State private var isManagingTags = false
    @State private var isShowingPremiumPaywall = false
    @State private var pendingIconChoice: AppIconChoice?

    var body: some View {
        NavigationStack {
            List {
                Section("Premium") {
                    Button {
                        pendingIconChoice = nil
                        isShowingPremiumPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: store.isPremiumUnlocked ? "checkmark.seal.fill" : "sparkles")
                                .foregroundStyle(BudgetSnapTheme.accent)
                                .font(.title3.weight(.semibold))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.isPremiumUnlocked ? "Premium Unlocked" : "Unlock Premium")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("iCloud sharing and alternate app icons")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if !store.isPremiumUnlocked {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(store.isPremiumUnlocked)
                }

                Section("Lists") {
                    Button {
                        isAddingList = true
                    } label: {
                        Label("Create New List", systemImage: "plus")
                    }

                    ForEach(store.spendLists) { list in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.title)
                                Text("\(list.itemCount) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(list.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        let lists = store.spendLists
                        offsets.map { lists[$0] }.forEach(store.deleteList)
                    }
                }

                Section("Transaction Tags") {
                    Button {
                        isManagingTags = true
                    } label: {
                        Label("Manage Tags", systemImage: "tag")
                    }

                    if store.categories.isEmpty {
                        Text("No tags")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.categories) { tag in
                            Label(tag.name, systemImage: tag.icon)
                                .foregroundStyle(tag.tint)
                        }
                    }
                }

                Section("App Icon") {
                    NavigationLink {
                        AppIconPickerView(store: store)
                    } label: {
                        HStack(spacing: 12) {
                            IconColorSwatch(choice: store.selectedAppIcon, appearance: store.selectedAppIconAppearance)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Change App Icon")
                                    .foregroundStyle(.primary)

                                Text("\(store.selectedAppIcon.title), \(store.selectedAppIconAppearance.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("About") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    Text("Built by Andrew Williams using Codex. Inspired by Jordan Morgan's Spend Stack app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isAddingList) {
                AddListView { title, total in
                    store.addList(title: title, total: total)
                }
            }
            .sheet(isPresented: $isManagingTags) {
                TagManagerView(store: store)
            }
            .sheet(isPresented: $isShowingPremiumPaywall) {
                PremiumPaywallView(store: store) {
                    if let pendingIconChoice {
                        applyUnlockedIcon(pendingIconChoice)
                        self.pendingIconChoice = nil
                    }
                }
            }
        }
    }

    private func applyIcon(_ choice: AppIconChoice) {
        guard !choice.requiresPremium || store.isPremiumUnlocked else {
            pendingIconChoice = choice
            isShowingPremiumPaywall = true
            return
        }

        applyUnlockedIcon(choice)
    }

    private func applyUnlockedIcon(_ choice: AppIconChoice) {
        store.selectAppIcon(choice)
    }
}

struct AppIconPickerView: View {
    @ObservedObject var store: BudgetStore
    @State private var appearance: AppIconAppearance
    @State private var isShowingPremiumPaywall = false
    @State private var pendingSelection: (AppIconChoice, AppIconAppearance)?

    init(store: BudgetStore) {
        self.store = store
        _appearance = State(initialValue: store.selectedAppIconAppearance)
    }

    var body: some View {
        List {
            Section {
                ForEach(AppIconChoice.allCases) { choice in
                    Button {
                        choose(choice, appearance: appearance)
                    } label: {
                        HStack(spacing: 16) {
                            IconColorSwatch(choice: choice, appearance: appearance)
                                .frame(width: 54, height: 54)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(choice.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("Budget Stack")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BudgetSnapTheme.accent)
                            }

                            Spacer()

                            if needsPremium(choice: choice, appearance: appearance) && !store.isPremiumUnlocked {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                            } else if store.selectedAppIcon == choice && store.selectedAppIconAppearance == appearance {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(BudgetSnapTheme.accent)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("Select Icon")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Picker("Icon Appearance", selection: $appearance) {
                ForEach(AppIconAppearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .onChange(of: appearance) { _, newValue in
            guard !needsPremium(choice: store.selectedAppIcon, appearance: newValue) || store.isPremiumUnlocked else {
                pendingSelection = (store.selectedAppIcon, newValue)
                appearance = store.selectedAppIconAppearance
                isShowingPremiumPaywall = true
                return
            }

            choose(store.selectedAppIcon, appearance: newValue)
        }
        .sheet(isPresented: $isShowingPremiumPaywall) {
            PremiumPaywallView(store: store) {
                if let pendingSelection {
                    appearance = pendingSelection.1
                    applyIcon(pendingSelection.0, appearance: pendingSelection.1)
                    self.pendingSelection = nil
                }
            }
        }
    }

    private func choose(_ choice: AppIconChoice, appearance: AppIconAppearance) {
        guard !needsPremium(choice: choice, appearance: appearance) || store.isPremiumUnlocked else {
            pendingSelection = (choice, appearance)
            isShowingPremiumPaywall = true
            return
        }

        applyIcon(choice, appearance: appearance)
    }

    private func applyIcon(_ choice: AppIconChoice, appearance: AppIconAppearance) {
        store.selectAppIcon(choice, appearance: appearance)

        guard UIApplication.shared.supportsAlternateIcons else { return }

        let iconName = choice.alternateIconName(for: appearance)
        guard UIApplication.shared.alternateIconName != iconName else { return }

        UIApplication.shared.setAlternateIconName(iconName)
    }

    private func needsPremium(choice: AppIconChoice, appearance: AppIconAppearance) -> Bool {
        choice.requiresPremium || appearance == .dark
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Privacy Policy") {
                Text("Budget Stack does not collect, sell, or share personal data.")

                Text("Your lists, transactions, tags, settings, and app preferences are stored on your device. Budget Stack does not send this information to Andrew Williams, Codex, OpenAI, or any third-party analytics service.")

                Text("If you choose to use future iCloud sharing features, Apple may process the information needed to sync or share your data through iCloud according to your Apple account and iCloud settings.")
            }

            Section("Data Collected") {
                LabeledContent("Personal Data", value: "None")
                LabeledContent("Analytics", value: "None")
                LabeledContent("Tracking", value: "None")
            }

            Section("Contact") {
                Text("For privacy questions, contact the app developer, Andrew Williams.")
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PremiumPaywallView: View {
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    var dismissAfterUnlock = true
    var onUnlock: () -> Void = {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(BudgetSnapTheme.accent.opacity(0.16))
                            .frame(width: 86, height: 86)

                        Image(systemName: "sparkles")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(BudgetSnapTheme.accent)
                    }

                    Text("Budget Stack Premium")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Unlock iCloud list sharing and alternate app icons with one purchase.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                }

                VStack(spacing: 14) {
                    PremiumFeatureRow(icon: "person.2.fill", title: "iCloud Sharing", subtitle: "Share a list with someone else.")
                    PremiumFeatureRow(icon: "app.badge.fill", title: "Alternate App Icons", subtitle: "Choose from premium Budget Stack icon colors.")
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        unlock()
                    } label: {
                        Text(store.isPremiumUnlocked ? "Premium Unlocked" : "Unlock Premium")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isPremiumUnlocked)

                    Button("Restore Purchase") {
                        unlock()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 34)
            .padding(.bottom, 28)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func unlock() {
        store.unlockPremium()
        onUnlock()

        if dismissAfterUnlock {
            dismiss()
        }
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BudgetSnapTheme.accent)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .budgetGlass(cornerRadius: 12, interactive: false)
    }
}

struct TagManagerView: View {
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var newTagName = ""
    @State private var selectedColor = "mint"

    private let colors = ["mint", "yellow", "pink", "teal", "indigo", "blue"]

    var body: some View {
        NavigationStack {
            List {
                Section("New Tag") {
                    TextField("Tag name", text: $newTagName)

                    Picker("Color", selection: $selectedColor) {
                        ForEach(colors, id: \.self) { color in
                            Text(color.capitalized)
                                .tag(color)
                        }
                    }

                    Button {
                        store.addTag(name: newTagName, colorName: selectedColor)
                        newTagName = ""
                    } label: {
                        Label("Add Tag", systemImage: "plus")
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Tags") {
                    ForEach(store.categories) { tag in
                        Label(tag.name, systemImage: tag.icon)
                            .foregroundStyle(tag.tint)
                    }
                    .onDelete { offsets in
                        let tags = store.categories
                        offsets.map { tags[$0] }.forEach(store.deleteTag)
                    }
                }
            }
            .navigationTitle("Tags")
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

struct IconColorSwatch: View {
    let choice: AppIconChoice
    var appearance: AppIconAppearance = .regular

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(gradient)
            .frame(width: 36, height: 36)
            .overlay {
                AppIconPaperMark(accent: accent)
                    .padding(6)
            }
    }

    private var gradient: LinearGradient {
        if appearance == .dark {
            switch choice {
            case .blue:
                return LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.24), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .mint:
                return LinearGradient(colors: [Color(red: 0.06, green: 0.24, blue: 0.19), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .graphite:
                return LinearGradient(colors: [Color(red: 0.18, green: 0.19, blue: 0.22), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .sunset:
                return LinearGradient(colors: [Color(red: 0.36, green: 0.13, blue: 0.12), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }

        switch choice {
        case .blue:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mint:
            return LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .graphite:
            return LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sunset:
            return LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var accent: Color {
        switch choice {
        case .blue:
            .blue
        case .mint:
            .teal
        case .graphite:
            Color(uiColor: .darkGray)
        case .sunset:
            .pink
        }
    }
}

struct AppIconPaperMark: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                TornPaperShape()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 1)

                VStack(spacing: height * 0.12) {
                    Rectangle()
                        .fill(.gray.opacity(0.16))
                        .frame(width: width * 0.42, height: 1)

                    Text("$")
                        .font(.system(size: height * 0.45, weight: .black))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Rectangle()
                        .fill(.gray.opacity(0.16))
                        .frame(width: width * 0.38, height: 1)
                }
                .padding(.bottom, height * 0.07)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
    }
}

struct TornPaperShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width * 0.10
        let tearY = rect.maxY - rect.height * 0.13

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: tearY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.maxY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.70, y: tearY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.maxY - rect.height * 0.03))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: tearY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX, y: tearY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: BudgetStore())
    }
}
