import Foundation

/// Manages user-defined card nicknames and payment instrument metadata.
/// Stored persistently in UserDefaults so card tokens (e.g. "8031") render
/// with meaningful financial institution and account names.
enum CardPortfolio {

    private static let storageKey = "macsync.cardNicknames"

    /// Primary card bindings requested by the user:
    /// - 8031: Steve Credit
    /// - 1533: Joyce Credit
    /// - 9530: Lucas Credit
    /// - 7805: Chase Checking
    /// - 1244: Chase ATM
    static let defaultNicknames: [String: String] = [
        "8031": "Steve Credit",
        "1533": "Joyce Credit",
        "9530": "Lucas Credit",
        "7805": "Chase Checking",
        "1244": "Chase ATM"
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

    /// Resets custom nicknames to standard defaults.
    static func resetDefaults() {
        UserDefaults.standard.removeObject(forKey: storageKey)
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

    /// Returns the user-friendly display name (e.g. "Steve Credit ••8031" or "Direct Web").
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

    /// Returns the short label for compact UI pills (e.g. "Steve Credit" or "••8031").
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
