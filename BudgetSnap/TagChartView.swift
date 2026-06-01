import SwiftUI

struct TagChartView: View {
    @ObservedObject var store: BudgetStore
    let list: SpendList?
    @Environment(\.dismiss) private var dismiss

    private var summaries: [SpendingSummary] {
        store.summaries(for: list)
            .filter { $0.spent > 0 }
            .sorted { $0.spent > $1.spent }
    }

    private var total: Decimal {
        store.transactions(for: list).reduce(0) { $0 + $1.amount }
    }

    private var maxSpent: Double {
        summaries
            .map { NSDecimalNumber(decimal: $0.spent).doubleValue }
            .max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BudgetSnapTheme.background.ignoresSafeArea()

                if summaries.isEmpty {
                    ContentUnavailableView(
                        "No Tag Spending",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Add transactions with tags to see your spending breakdown.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Text(total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(BudgetSnapTheme.primaryText)
                                .monospacedDigit()
                                .padding(.horizontal, 24)
                                .padding(.top, 16)

                            VStack(spacing: 18) {
                                ForEach(summaries) { summary in
                                    TagBarRow(summary: summary, maxSpent: maxSpent)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Tags")
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

struct TagBarRow: View {
    let summary: SpendingSummary
    let maxSpent: Double

    private var fraction: Double {
        guard maxSpent > 0 else { return 0 }
        let spent = NSDecimalNumber(decimal: summary.spent).doubleValue
        return min(max(spent / maxSpent, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(summary.category.name, systemImage: summary.category.icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BudgetSnapTheme.primaryText)

                Spacer()

                Text(summary.spent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BudgetSnapTheme.primaryText)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemFill))

                    Capsule()
                        .fill(summary.category.tint)
                        .frame(width: max(proxy.size.width * fraction, 8))
                }
            }
            .frame(height: 16)
        }
    }
}

struct TagChartView_Previews: PreviewProvider {
    static var previews: some View {
        TagChartView(store: BudgetStore(), list: nil)
    }
}
