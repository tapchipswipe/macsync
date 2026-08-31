import Foundation

/// Manages user-defined card nicknames and payment instrument metadata.
/// Stored persistently in UserDefaults so card tokens (e.g. "8031") render
/// with meaningful financial institution and account names.
enum CardPortfolio {

    private static let storageKey = "macsync.cardNicknames"

    /// Default known card bindings inferred from verified statement receipts.
    static let defaultNicknames: [String: String] = [
        "8031": "Chase Visa",
        "7805": "Chase Checking",
        "9530": "Chase Prime",
        "1533": "Everyday Debit",
        "1244": "Chase ATM",
        "2211": "Venmo Backup",
        "4430": "Venmo Balance"
    ]

    /// Persistent custom card nicknames.
    static var nicknames: [String: String] {
        get {
            guard let raw = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] else {
                return defaultNicknames
            }
            var merged = defaultNicknames
            for (k, v) in raw {
                merged[k] = v
            }
            return merged
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }

    /// Sets or updates a custom nickname for a specific card last 4.
    static func setNickname(_ name: String, for cardLast4: String) {
        var current = nicknames
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty {
            current.removeValue(forKey: cardLast4)
        } else {
            current[cardLast4] = cleanName
        }
        nicknames = current
    }

    /// Returns the user-friendly display name (e.g. "Chase Visa ••8031" or "Direct Web").
    static func displayName(for cardLast4: String?) -> String {
        guard let card = cardLast4?.trimmingCharacters(in: .whitespacesAndNewlines),
              !card.isEmpty, card.lowercased() != "unknown" else {
            return "Direct Web"
        }
        if let name = nicknames[card] {
            return "\(name) ••\(card)"
        }
        if card.count == 4 && card.allSatisfy(\.isNumber) {
            return "Card ••\(card)"
        }
        return card
    }

    /// Returns the short label for compact UI pills (e.g. "Chase Visa" or "••8031").
    static func shortName(for cardLast4: String?) -> String {
        guard let card = cardLast4?.trimmingCharacters(in: .whitespacesAndNewlines),
              !card.isEmpty, card.lowercased() != "unknown" else {
            return "Direct"
        }
        if let name = nicknames[card] {
            return name
        }
        if card.count == 4 && card.allSatisfy(\.isNumber) {
            return "••\(card)"
        }
        return card
    }
}
