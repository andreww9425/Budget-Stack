import Foundation
import SwiftUI

struct BudgetCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var colorName: String
    var monthlyLimit: Decimal

    var tint: Color {
        switch colorName {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        case "gray": .gray
        default: .blue
        }
    }

    static let tagColorNames = [
        "red",
        "orange",
        "yellow",
        "green",
        "mint",
        "teal",
        "cyan",
        "blue",
        "indigo",
        "purple",
        "pink",
        "brown",
        "gray"
    ]

    static let tagIconNames = [
        "house.fill",
        "sparkles",
        "fork.knife",
        "cart.fill",
        "bolt.fill",
        "tshirt.fill",
        "fuelpump.fill",
        "car.fill",
        "cross.case.fill",
        "heart.fill",
        "stethoscope",
        "pills.fill",
        "bag.fill",
        "creditcard.fill",
        "banknote.fill",
        "dollarsign.circle.fill",
        "gift.fill",
        "gamecontroller.fill",
        "popcorn.fill",
        "figure.run",
        "dumbbell.fill",
        "airplane",
        "tram.fill",
        "bus.fill",
        "graduationcap.fill",
        "book.fill",
        "pawprint.fill",
        "leaf.fill",
        "wrench.and.screwdriver.fill",
        "hammer.fill",
        "wifi",
        "phone.fill",
        "desktopcomputer",
        "cart.badge.plus",
        "shippingbox.fill",
        "tag.fill"
    ]

    static func tint(for colorName: String) -> Color {
        BudgetCategory(name: "", icon: "", colorName: colorName, monthlyLimit: 0).tint
    }

    static func displayName(for colorName: String) -> String {
        switch colorName {
        case "cyan": "Cyan"
        case "gray": "Gray"
        default: colorName.capitalized
        }
    }
}

struct Transaction: Identifiable, Codable, Hashable {
    var id = UUID()
    var listID: SpendList.ID
    var title: String
    var merchant: String
    var amount: Decimal
    var date: Date
    var categoryID: BudgetCategory.ID
    var isChecked = false
    var recurrence: TransactionRecurrence = .oneTime
    var privateNote = ""

    enum CodingKeys: String, CodingKey {
        case id
        case listID
        case title
        case merchant
        case amount
        case date
        case categoryID
        case isChecked
        case recurrence
        case privateNote
    }

    init(
        id: UUID = UUID(),
        listID: SpendList.ID = SpendList.appleCardID,
        title: String,
        merchant: String,
        amount: Decimal,
        date: Date,
        categoryID: BudgetCategory.ID,
        isChecked: Bool = false,
        recurrence: TransactionRecurrence = .oneTime,
        privateNote: String = ""
    ) {
        self.id = id
        self.listID = listID
        self.title = title
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.categoryID = categoryID
        self.isChecked = isChecked
        self.recurrence = recurrence
        self.privateNote = privateNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        listID = try container.decodeIfPresent(SpendList.ID.self, forKey: .listID) ?? SpendList.appleCardID
        title = try container.decode(String.self, forKey: .title)
        merchant = try container.decode(String.self, forKey: .merchant)
        amount = try container.decode(Decimal.self, forKey: .amount)
        date = try container.decode(Date.self, forKey: .date)
        categoryID = try container.decode(BudgetCategory.ID.self, forKey: .categoryID)
        isChecked = try container.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        recurrence = try container.decodeIfPresent(TransactionRecurrence.self, forKey: .recurrence) ?? .oneTime
        privateNote = try container.decodeIfPresent(String.self, forKey: .privateNote) ?? ""
    }
}

enum TransactionRecurrence: String, Codable, CaseIterable, Identifiable, Hashable {
    case oneTime
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneTime: "One-Time"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var isRecurring: Bool {
        self != .oneTime
    }
}

struct SpendingSummary: Identifiable {
    var id: BudgetCategory.ID { category.id }
    var category: BudgetCategory
    var spent: Decimal

    var remaining: Decimal {
        max(category.monthlyLimit - spent, 0)
    }

    var progress: Double {
        guard category.monthlyLimit > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: spent / category.monthlyLimit).doubleValue
        return min(max(value, 0), 1)
    }
}

struct SpendList: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var itemCount: Int
    var total: Decimal
    var isShared = false
    var kind: SpendListKind = .staticList
}

enum SpendListKind: String, Codable, Hashable {
    case appleCard
    case staticList
}

enum AppIconChoice: String, Codable, CaseIterable, Identifiable {
    case blue
    case mint
    case graphite
    case sunset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "Budget Blue"
        case .mint: "Mint"
        case .graphite: "Graphite"
        case .sunset: "Sunset"
        }
    }

    var isAvailable: Bool {
        true
    }

    var requiresPremium: Bool {
        self != .blue
    }

    var alternateIconName: String? {
        alternateIconName(for: .regular)
    }

    func alternateIconName(for appearance: AppIconAppearance) -> String? {
        switch self {
        case .blue:
            appearance == .dark ? "AppIconBlueDark" : nil
        case .mint:
            appearance == .dark ? "AppIconMintDark" : "AppIconMint"
        case .graphite:
            appearance == .dark ? "AppIconGraphiteDark" : "AppIconGraphite"
        case .sunset:
            appearance == .dark ? "AppIconSunsetDark" : "AppIconSunset"
        }
    }
}

enum AppIconAppearance: String, Codable, CaseIterable, Identifiable {
    case regular
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular: "Regular"
        case .dark: "Dark"
        }
    }
}

extension Decimal {
    static func / (lhs: Decimal, rhs: Decimal) -> Decimal {
        var left = lhs
        var right = rhs
        var result = Decimal()
        NSDecimalDivide(&result, &left, &right, .plain)
        return result
    }
}

extension BudgetCategory {
    static let groceriesID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let restaurantID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let billsID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let transitID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let funID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let miscellaneousID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

    static var miscellaneous: BudgetCategory {
        BudgetCategory(id: miscellaneousID, name: "Miscellaneous", icon: "tag.fill", colorName: "blue", monthlyLimit: 0)
    }

    static let sample: [BudgetCategory] = [
        BudgetCategory(id: groceriesID, name: "Groceries", icon: "cart.fill", colorName: "mint", monthlyLimit: 520),
        BudgetCategory(id: restaurantID, name: "Restaurant", icon: "fork.knife", colorName: "yellow", monthlyLimit: 430),
        BudgetCategory(id: billsID, name: "Bills", icon: "bolt.fill", colorName: "teal", monthlyLimit: 340),
        BudgetCategory(id: transitID, name: "Transit", icon: "tram.fill", colorName: "indigo", monthlyLimit: 180),
        BudgetCategory(id: funID, name: "Fun", icon: "sparkles", colorName: "pink", monthlyLimit: 220),
        miscellaneous
    ]
}

extension SpendList {
    static let appleCardID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    static let appleSavingsID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    static let awWantListID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    static let newHomeID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    static let lowesCardID = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
}
