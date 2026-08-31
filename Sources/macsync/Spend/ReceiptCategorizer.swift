import Foundation

/// Keyword rules to categorize a merchant, with user overrides taking
/// precedence (stored in UserDefaults by merchant name).
enum ReceiptCategorizer {

    // MARK: - Keyword rules

    private static let rules: [(category: ReceiptCategory, needles: [String])] = [
        (.dining, ["starbucks", "chipotle", "dunkin", "doordash", "uber eats", "grubhub", "cava", "sweetgreen", "shakeshack", "mcdonald", "wendy", "panera"]),
        (.groceries, ["walmart", "target", "costco", "trader joe", "whole foods", "kroger", "safeway", "aldi", "wegmans", "stop & shop", "instacart"]),
        (.software, ["adobe", "github", "figma", "notion", "canva", "microsoft", "epic games", "playstation", "nintendo", "jetbrains", "linear", "cline bot", "retell"]),
        (.subscriptions, ["netflix", "spotify", "hulu", "disney+", "hbomax", "max", "peacock", "paramount+", "apple", "youtube premium", "amazon prime"]),
        (.travel, ["delta", "southwest", "united", "american airlines", "airbnb", "hotels.com", "booking.com", "expedia", "marriott", "hilton", "airline"]),
        (.transport, ["uber", "lyft", "grab", "bolt", "trainline", "amtrak", "gas station", "shell", "chevron", "exxon"]),
        (.utilities, ["xfinity", "comcast", "verizon", "t-mobile", "att", "at&t", "duke energy", "coned", "pseg", "water", "electric"]),
        (.health, ["cvs", "walgreens", "planet fitness", "equinox", "pharmacy", "doctor", "dental", "hospital", "rythm health", "marrs ear", "marrs"]),
        (.education, ["coursera", "udemy", "skillshare", "masterclass", "udacity", "saint anselm", "textbook", "tuition", "florida school of insurance"]),
        (.shopping, ["amazon", "best buy", "nike", "adidas", "zara", "uniqlo", "etsy", "ebay", "shein", "apparel", "clothing", "fat and the moon", "project cloud", "swell labs", "latex mattress", "charles tyrwhitt", "ctshirts"])
    ]

    // MARK: - User overrides

    private static let overridesKey = "macsync.receiptCategoryOverrides"

    static var overrides: [String: ReceiptCategory] {
        get {
            guard let raw = UserDefaults.standard.dictionary(forKey: overridesKey) as? [String: String] else { return [:] }
            var out: [String: ReceiptCategory] = [:]
            for (k, v) in raw {
                if let cat = ReceiptCategory(rawValue: v) { out[k.lowercased()] = cat }
            }
            return out
        }
        set {
            let raw = newValue.reduce(into: [String: String]()) { $0[$1.key] = $1.value.rawValue }
            UserDefaults.standard.set(raw, forKey: overridesKey)
        }
    }

    /// Category for a merchant, honoring user overrides first.
    static func category(for merchant: String) -> ReceiptCategory {
        let key = merchant.lowercased()
        if let override = overrides[key] { return override }
        for (cat, needles) in rules where needles.contains(where: { key.contains($0) }) {
            return cat
        }
        return .other
    }

    static func setOverride(_ category: ReceiptCategory, for merchant: String) {
        var o = overrides
        o[merchant.lowercased()] = category
        overrides = o
    }

    static func clearOverride(for merchant: String) {
        var o = overrides
        o.removeValue(forKey: merchant.lowercased())
        overrides = o
    }
}