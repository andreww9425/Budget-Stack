import SwiftUI

struct AddListView: View {
    let onSave: (String, Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startingTotal = ""

    private var parsedTotal: Decimal {
        Decimal(string: startingTotal.filter { "0123456789.".contains($0) }) ?? 0
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List") {
                    TextField("Name", text: $title)
                    TextField("Starting total", text: $startingTotal)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, parsedTotal)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

struct AddListView_Previews: PreviewProvider {
    static var previews: some View {
        AddListView { _, _ in }
    }
}
