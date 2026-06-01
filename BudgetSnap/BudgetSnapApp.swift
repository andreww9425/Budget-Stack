import SwiftUI

@main
struct BudgetSnapApp: App {
    @StateObject private var store = BudgetStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .dynamicTypeSize(.xSmall ... .accessibility1)
        }
    }
}
