import Foundation

/// Result of parsing a candidate receipt message. Field-level confidence lets
/// the UI surface low-confidence hits for one-tap confirmation instead of
/// silently filing a wrong amount.
struct ParsedReceipt {
    var merchant: String?
    var amount: Decimal?
    var currency: String?
    var cardLast4: String?
    var transactionDate: Date?
    var confidence: Double
    var needsReview: Bool
}

/// Pure text → receipt parser. No I/O, unit-testable. Heuristics are
/// order-independent; the strongest, most narrowly-scoped match wins (an
/// explicit "Total: $…" beats the first bare "$…" in the body).
enum ReceiptParser {

    // MARK: - Merchant templates (~40 known senders)

    private struct SenderRule {
        let domain: String
        let merchant: String
        let category: ReceiptCategory
    }

    private static let senderRules: [SenderRule] = [
        SenderRule(domain: "amazon.com", merchant: "Amazon", category: .shopping),
        SenderRule(domain: "amazonaws.com", merchant: "Amazon Web Services", category: .software),
        SenderRule(domain: "shopify.com", merchant: "Shopify", category: .business),
        SenderRule(domain: "apple.com", merchant: "Apple", category: .subscriptions),
        SenderRule(domain: "adobereceipts.com", merchant: "Adobe", category: .software),
        SenderRule(domain: "netflix.com", merchant: "Netflix", category: .subscriptions),
        SenderRule(domain: "spotify.com", merchant: "Spotify", category: .subscriptions),
        SenderRule(domain: "microsoft.com", merchant: "Microsoft", category: .software),
        SenderRule(domain: "xbox.com", merchant: "Microsoft", category: .software),
        SenderRule(domain: "google.com", merchant: "Google", category: .subscriptions),
        SenderRule(domain: "paypal.com", merchant: "PayPal", category: .business),
        SenderRule(domain: "stripe.com", merchant: "Stripe", category: .business),
        SenderRule(domain: "squareup.com", merchant: "Square", category: .business),
        SenderRule(domain: "ubereats.com", merchant: "Uber Eats", category: .dining),
        SenderRule(domain: "uber.com", merchant: "Uber", category: .transport),
        SenderRule(domain: "doordash.com", merchant: "DoorDash", category: .dining),
        SenderRule(domain: "grubhub.com", merchant: "Grubhub", category: .dining),
        SenderRule(domain: "lyft.com", merchant: "Lyft", category: .transport),
        SenderRule(domain: "starbucks.com", merchant: "Starbucks", category: .dining),
        SenderRule(domain: "chipotle.com", merchant: "Chipotle", category: .dining),
        SenderRule(domain: "dunkindonuts.com", merchant: "Dunkin'", category: .dining),
        SenderRule(domain: "walmart.com", merchant: "Walmart", category: .shopping),
        SenderRule(domain: "target.com", merchant: "Target", category: .shopping),
        SenderRule(domain: "bestbuy.com", merchant: "Best Buy", category: .shopping),
        SenderRule(domain: "costco.com", merchant: "Costco", category: .shopping),
        SenderRule(domain: "delta.com", merchant: "Delta Air Lines", category: .travel),
        SenderRule(domain: "southwest.com", merchant: "Southwest Airlines", category: .travel),
        SenderRule(domain: "united.com", merchant: "United Airlines", category: .travel),
        SenderRule(domain: "airbnb.com", merchant: "Airbnb", category: .travel),
        SenderRule(domain: "xfinity.com", merchant: "Xfinity", category: .utilities),
        SenderRule(domain: "comcast.net", merchant: "Xfinity", category: .utilities),
        SenderRule(domain: "verizon.com", merchant: "Verizon", category: .utilities),
        SenderRule(domain: "tmobile.com", merchant: "T-Mobile", category: .utilities),
        SenderRule(domain: "att.com", merchant: "AT&T", category: .utilities),
        SenderRule(domain: "steampowered.com", merchant: "Steam", category: .software),
        SenderRule(domain: "epicgames.com", merchant: "Epic Games", category: .software),
        SenderRule(domain: "playstation.com", merchant: "PlayStation", category: .software),
        SenderRule(domain: "github.com", merchant: "GitHub", category: .software),
        SenderRule(domain: "figma.com", merchant: "Figma", category: .software),
        SenderRule(domain: "notion.com", merchant: "Notion", category: .software),
        SenderRule(domain: "canva.com", merchant: "Canva", category: .software),
        SenderRule(domain: "planetfitness.com", merchant: "Planet Fitness", category: .health),
        SenderRule(domain: "equinox.com", merchant: "Equinox", category: .health),
        SenderRule(domain: "cvshealth.com", merchant: "CVS", category: .health),
        SenderRule(domain: "walgreens.com", merchant: "Walgreens", category: .health)
    ]

    // MARK: - Enter / parse

    /// Cheap subject/sender heuristic used to shortlist messages before their
    /// bodies are fetched. Single source of truth shared by the collector.
    static func looksLikeReceipt(subject: String, sender: String) -> Bool {
        // Declined / failed payments are NOT purchases — never count them.
        if looksLikeFailedPayment(subject: subject, sender: sender) { return false }
        let subj = subject.lowercased()
        let subjectWords = ["receipt", "invoice", "payment", "your order", "order confirmation",
                            "purchase", "statement", "charged", "paid", "shipment", "on the way",
                            "delivered", "transaction", "subscription", "order", "bill",
                            "confirmed", "your trade", "paid you"]
        if subjectWords.contains(where: { subj.contains($0) }) { return true }
        return senderRules.contains { sender.lowercased().contains($0.domain.lowercased()) }
    }

    /// Declined / unsuccessful payments must never be counted as spending.
    /// Matches the common bank/processor phrasings (Privacy.com pseudo-card
    /// decline alerts, Stripe "unsuccessful payment" retries, etc.).
    static func looksLikeFailedPayment(subject: String, sender: String) -> Bool {
        let subj = subject.lowercased()
        let declineWords = ["decline", "unsuccessful", "payment failed", "failed payment",
                            "was declined", "could not be processed", "couldn't be processed",
                            "payment attempt failed", "fix your payment", "action required: update"]
        if declineWords.contains(where: { subj.contains($0) }) { return true }
        let s = sender.lowercased()
        return s.hasPrefix("failed-payments") || s.contains("failed-payments@")
    }

    /// Rejects messages that look receipt-like but are not real purchases:
/// - Declined / failed charges (already checked in looksLikeFailedPayment but
///   we also scan the body for cases the subject doesn't mention).
/// - Zero-dollar totals (e.g. statement notices, account summaries).
/// - Explicit "no charge" / "free" confirmations.
/// - Non-transactional pseudo-card notifications (e.g. Flux/Team Privacy).
static func shouldRejectNonTransaction(subject: String, sender: String, body: String, amount: Decimal?) -> Bool {
    let text = (subject + "\n" + body).lowercased()

    // 1. Declined language in body even if subject didn't carry it.
    let declineWords = ["declined", "was declined", "payment failed", "unsuccessful payment",
                        "could not be processed", "couldn't be processed", "fix your payment",
                        "payment attempt failed", "charge failed", "authorization failed",
                        "not authorized", "rejected by bank"]
    if declineWords.contains(where: { text.contains($0) }) { return true }

    // 2. $0 total — never a real purchase.
    if let amt = amount, amt == 0 { return true }

    // 3. "No charge" / "free" confirmation (e.g. $0 trial, free order).
    if text.contains("no charge") || text.contains("charged $0") { return true }

        // 4. Pseudo-card / promotional notifications that carry a card mask
    //    but no actual purchase (Flux Team Privacy, etc.).
    let senderLC = sender.lowercased()
    let promoSenders = ["teamprivacy", "team@privacy", "noreply@privacy", "flux.ai"]
    if promoSenders.contains(where: { senderLC.contains($0) }) { return true }

    // 5. Transactional/marketing platforms that often carry dollar amounts
    //    in notifications (statements, promo codes, balance updates) but
    //    are not purchase confirmations.
    let promoDomains = ["klaviyomail.com", "sender-sib.com", "broadridge.net",
                        "amazonses.com", "sendgrid.net", "mailgun", "postmark"]
    // Only reject when there's no strong purchase confirmation in the subject.
    // (amazonses sends both real receipts and marketing; if the subject
    //  contains "receipt" or "order", let it through.)
    let subjLC = subject.lowercased()
    if !subjLC.contains("receipt") && !subjLC.contains("order") && !subjLC.contains("invoice") {
        if promoDomains.contains(where: { senderLC.contains($0) }) { return true }
    }

    // 6. Subject lines that are clearly not purchases even if they
    //    mention a dollar amount (notifications, updates, confirmations
    //    of non-financial events).
    let nonPurchaseSubjects = ["notification", "reminder", "update", "your account",
                               "security alert", "password", "verification code",
                               "new sign-in", "login", "newsletter", "weekly recap"]
    if nonPurchaseSubjects.contains(where: { subjLC.contains($0) }) && !subjLC.contains("receipt") && !subjLC.contains("invoice") && !subjLC.contains("order") {
        return true
    }

    return false
}

/// Parses one candidate receipt message. `sentDate` is the message date
    /// (used when no explicit purchase date can be found in the body).
    static func parse(subject: String, sender: String, body: String, sentDate: Date) -> ParsedReceipt {
        let merchant = resolveMerchant(subject: subject, sender: sender)
                var amount = firstAmount(in: body)
        let labeled = hasLabeledTotal(in: body)
        let card = cardLast4(in: body.replacingOccurrences(of: "\n", with: " "))
        let date = purchaseDate(in: subject, body: body) ?? sentDate

        var confidence = 0.35                              // baseline: weak guess
        if merchant != nil { confidence += 0.20 }
                if amount != nil { confidence += 0.25 }
        // Hard rejects (declined / non-transactions): zero out everything so
        // the caller treats this as a non-receipt.
        if shouldRejectNonTransaction(subject: subject, sender: sender, body: body, amount: amount) {
            confidence = 0
            amount = nil
        }
        if labeled { confidence += 0.15 }
        if card != nil { confidence += 0.15 }
        if merchantWasKnown(sender) { confidence += 0.10 }
        confidence = min(1.0, confidence)

        return ParsedReceipt(
            merchant: merchant,
            amount: amount,
            currency: firstCurrency(in: body) ?? "USD",
            cardLast4: card,
            transactionDate: date,
            confidence: confidence,
            needsReview: confidence < 0.75
        )
    }

    // MARK: - Amount

    /// Strongest-signal amount first: labeled totals beat bare "$x".
    static func firstAmount(in text: String) -> Decimal? {
        if let labeled = firstMatch(#"(?:total|amount due|charged|paid)[^0-9$€£]{0,25}?[$€£]\s?([0-9][0-9,]*\.?[0-9]{0,2})"#, in: text),
           let d = moneyDecimal(labeled) { return d }
        return firstMoney(in: text)
    }

    static func hasLabeledTotal(in text: String) -> Bool {
        firstMatch(#"(?:total|amount due)[^0-9$€£]{0,25}?[$€£]"#, in: text) != nil
    }

    /// First bare currency amount ("$42.95", "USD 42.95", "$ 1,234.56").
    static func firstMoney(in text: String) -> Decimal? {
        let patterns = [
            #"[$€£]\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"\b(?:USD|CAD|EUR|GBP|AUD)\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#
        ]
        for p in patterns {
            if let m = firstMatch(p, in: text, group: 1), let d = moneyDecimal(m) {
                return d
            }
        }
        return nil
    }

    static func moneyDecimal(_ raw: String) -> Decimal? {
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.range(of: #"^[0-9]*\.?[0-9]{0,2}$"#, options: .regularExpression) != nil,
              !cleaned.isEmpty,
              let d = Decimal(string: cleaned) else { return nil }
        return d
    }

    static func firstCurrency(in text: String) -> String? {
        if text.range(of: "€", options: .literal) != nil { return "EUR" }
        if text.range(of: "£", options: .literal) != nil { return "GBP" }
        if let m = firstMatch(#"\b(USD|CAD|EUR|GBP|AUD)\b"#, in: text) { return m.uppercased() }
        return text.range(of: "$", options: .literal) != nil ? "USD" : nil
    }

    // MARK: - Card last 4

    /// Matches the common phrasings: "Card ending in 1234", "ending •• 1234",
    /// "Visa •••• 1234", "•••• 1234", "XXXX 1234", "**** 1234".
    static func cardLast4(in text: String) -> String? {
        let patterns = [
            #"card[^0-9]{0,20}?ending(?: in| with)?[^0-9]{0,6}(\d{4})(?!\d)"#,
            #"ending in[^0-9]{0,6}(\d{4})(?!\d)"#,
            #"(?:visa|mastercard|amex|american express|discover)[^0-9]{0,12}?(\d{4})(?!\d)"#,
            #"[\u2022*x]{3,}\s?(\d{4})(?!\d)"#
        ]
        for p in patterns {
            if let m = firstMatch(p, in: text, group: 1) { return m }
        }
        return nil
    }

    // MARK: - Date

    static func purchaseDate(in subject: String, body: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        let labeled = subject + "\n" + body
        if let m = firstMatch(#"(?:purchase|transaction|order)?\s?date[^0-9A-Za-z]{1,8}([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}|[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4})"#, in: labeled, group: 1) {
            for fmt in ["MMM d, yyyy", "MMMM d, yyyy", "MM/dd/yyyy", "MM/dd/yy"] {
                f.dateFormat = fmt
                if let d = f.date(from: m) { return d }
            }
        }
        return nil
    }

    // MARK: - Merchant resolution

    private static func resolveMerchant(subject: String, sender: String) -> String? {
        // 1. Explicit "receipt/invoice from {Merchant}" in the subject is the
        //    most specific signal (Square-style receipts name the shop there).
        if let m = firstMatch(#"(?:receipt|invoice|payment)\s+(?:from|by)\s+([A-Za-z0-9][A-Za-z0-9&.' -]{1,40})"#, in: subject, group: 1) {
            return m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 2. "… bill for {X}" (Shopify billing), "order from {X}".
        if let m = firstMatch(#"(?:bill|invoice|order|payment)\s+for\s+([A-Za-z0-9][A-Za-z0-9&.' -]{1,40})"#, in: subject, group: 1) {
            return m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 3. "You paid {Person} $8.00" (P2P payments).
        if let m = firstMatch(#"you paid\s+([A-Za-z0-9][A-Za-z0-9 .'&-]{1,40}?)(?=\s*\$|\s+[0-9]|$)"#, in: subject, group: 1) {
            return m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 4. "Receipt from {Merchant}" (Square-style).
        if let m = firstMatch(#"receipt[^0-9A-Za-z]{1,4}from[^0-9A-Za-z]{1,4}([A-Za-z0-9][^,;]{1,40})"#, in: subject, group: 1) {
            return m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 5. Known sender domain (e.g. order-update@amazon.com).
        if let rule = senderRules.first(where: { sender.localizedLowercase.contains($0.domain.lowercased()) }) {
            return rule.merchant
        }
        return nil
    }

    private static func merchantWasKnown(_ sender: String) -> Bool {
        senderRules.contains { sender.localizedLowercase.contains($0.domain.lowercased()) }
    }

    // MARK: - Regex helper

    /// First regex match; `group` 0 returns the whole match.
    static func firstMatch(_ pattern: String, in text: String, group: Int = 0) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        let r = m.range(at: group)
        guard r.location != NSNotFound else { return nil }
        return ns.substring(with: r)
    }
}
