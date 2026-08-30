import Foundation

enum ReceiptParserTests {
    static func run() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)

        // ── Amazon: labeled total + card mask + known sender ──
        let amazon = ReceiptParser.parse(
            subject: "Your Amazon.com order of Toaster Oven",
            sender: "auto-confirm@amazon.com",
            body: "Hello,\nWe're confirming your order.\nTotal: $42.95\nPaid with Visa ending in 1234\nOrder #112-3456789",
            sentDate: d)
        expect(amazon.merchant == "Amazon", "Amazon merchant from known sender")
        expect(amazon.amount == Decimal(string: "42.95"), "Amazon labeled total")
        expect(amazon.cardLast4 == "1234", "Amazon card last4")
        expect(!amazon.needsReview, "Amazon high confidence, no review needed")

        // ── Square-style "receipt from {merchant}" ──
        let square = ReceiptParser.parse(
            subject: "Receipt from Joe's Coffee Shop",
            sender: "receipt@messaging.squareup.com",
            body: "Amount: $8.50\nCard •••• 9021\nThank you!",
            sentDate: d)
        expect(square.merchant == "Joe's Coffee Shop", "Square merchant from subject")
        expect(square.amount == Decimal(string: "8.50"), "Square 'Amount:' extraction")
        expect(square.cardLast4 == "9021", "Square dots mask card last4")
        expect(square.currency == "USD", "Square USD currency")

        // ── Bare currency fallback + low confidence → review ──
        let skimpy = ReceiptParser.parse(
            subject: "Payment confirmation",
            sender: "noreply@unknownshoppe.example",
            body: "You paid $19.99",
            sentDate: d)
        expect(skimpy.amount == Decimal(string: "19.99"), "bare $ amount parsed")
        expect(skimpy.merchant == nil, "unknown sender → no merchant guess")
        expect(skimpy.needsReview, "low confidence flagged for review")

        // ── Comma thousands ──
        expect(ReceiptParser.moneyDecimal("1,234.56") == Decimal(string: "1234.56"), "comma thousands stripped")

        // ── Dedup-relevant fields survive round-trip (payload level) ──
        let payload = ReceiptPayload(
            id: UUID(), merchant: "Amazon", amount: Decimal(string: "42.95")!,
            currency: "USD", cardLast4: "1234", category: .shopping,
            transactionDate: d, capturedAt: d, source: "mail",
            mailMessageID: "msg-1", confidence: 0.95, needsReview: false, notes: nil)
        let data = try! SyncFormat.jsonEncoder.encode(payload)
        let back = try! SyncFormat.jsonDecoder.decode(ReceiptPayload.self, from: data)
        expect(back.amount == Decimal(string: "42.95") && back.cardLast4 == "1234", "ReceiptPayload Codable roundtrip")

        // ── Purchase date within body ──
        let dated = ReceiptParser.parse(
            subject: "Your receipt",
            sender: "receipt@example.com",
            body: "Purchase date: Aug 12, 2026\nTotal: $5.00",
            sentDate: d)
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMM d, yyyy"
        expect(dated.transactionDate == f.date(from: "Aug 12, 2026"), "purchase date extracted from body")
    }
}

enum ReceiptCategorizerTests {
    static func run() {
        expect(ReceiptCategorizer.category(for: "Starbucks") == .dining, "Starbucks → dining")
        expect(ReceiptCategorizer.category(for: "Netflix") == .subscriptions, "Netflix → subscriptions")
        expect(ReceiptCategorizer.category(for: "Adobe") == .software, "Adobe → software")
        expect(ReceiptCategorizer.category(for: "Delta Air Lines") == .travel, "Delta → travel")
        expect(ReceiptCategorizer.category(for: "Uber") == .transport, "Uber → transport")
        expect(ReceiptCategorizer.category(for: "Verizon") == .utilities, "Verizon → utilities")
        expect(ReceiptCategorizer.category(for: "CVS") == .health, "CVS → health")
        expect(ReceiptCategorizer.category(for: "The Corner Bodega") == .other, "unknown → other")

        // User override beats rules.
        ReceiptCategorizer.setOverride(.business, for: "Starbucks")
        expect(ReceiptCategorizer.category(for: "Starbucks") == .business, "user override wins over keyword rule")
        ReceiptCategorizer.clearOverride(for: "Starbucks")
        expect(ReceiptCategorizer.category(for: "Starbucks") == .dining, "clear override restores keyword rule")

        // Category default deductibility.
        expect(ReceiptCategory.software.businessDeductible, "software default deductible")
        expect(ReceiptCategory.travel.businessDeductible, "travel default deductible")
        expect(!ReceiptCategory.dining.businessDeductible, "dining default personal")
    }
}

enum SpendAggregatorTests {
    static func run() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        func ev(_ m: String, _ amount: String, _ cat: ReceiptCategory, _ card: String?, _ review: Bool) -> TrackerEvent {
            TrackerEvent(ts: d, kind: .receipt, payload: .receipt(ReceiptPayload(
                id: UUID(), merchant: m, amount: Decimal(string: amount)!,
                currency: "USD", cardLast4: card, category: cat,
                transactionDate: d, capturedAt: d, source: "mail",
                mailMessageID: nil, confidence: review ? 0.5 : 0.95,
                needsReview: review, notes: nil)))
        }
        let events = [ev("Starbucks", "6.50", .dining, "1234", false),
                      ev("Netflix", "15.99", .subscriptions, "5678", false),
                      ev("Adobe", "59.99", .software, "1234", false),
                      ev("Old Bookstore", "5.00", .other, nil, true)]
        let s = SpendStats.calculate(events: events)
        expect(s.receipts.count == 4, "receipt count")
        expect(s.total == Decimal(string: "87.48"), "month total rollup")
        expect(s.deductibleTotal == Decimal(string: "75.98"), "deductible total = subscriptions+software")
        expect(s.byCategory[ReceiptCategory.dining] == Decimal(string: "6.50"), "by-category dining")
        expect(s.byCard["1234"] == Decimal(string: "66.49"), "by-card rollup")
        expect(s.byMerchant["Netflix"] == Decimal(string: "15.99"), "by-merchant rollup")
        expect(s.needsReviewCount == 1, "needs-review count")

        // Dedup by message id is the collector's job, but aggregating the same
        // payload twice WOULD double count — guard against that in tests.
        let twice = SpendStats.calculate(events: [events[0], events[0]])
        expect(twice.total == Decimal(string: "13.00"), "duplicate events roll up (expect double)")

        // Empty input.
        expect(SpendStats.calculate(events: []).receipts.isEmpty, "empty rollup")
    }
}

enum SpendExportTests {
    static func run() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let note = "lunch, w/ \"team\""
        let r = ReceiptPayload(id: UUID(), merchant: "Chipotle", amount: Decimal(string: "12.34")!,
                               currency: "USD", cardLast4: "9876", category: .dining,
                               transactionDate: d, capturedAt: d, source: "manual",
                               mailMessageID: nil, confidence: 1.0, needsReview: false, notes: note)
        let csv = SpendExport.csvString(receipts: [r])
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let expectHeader = "Date,Merchant,Category,Amount,Currency,CardLast4,Deductible,Source,Notes"
        expect(csv.hasPrefix(expectHeader), "CSV header")
        expect(csv.contains(f.string(from: d)), "CSV contains date")
        expect(csv.contains("\"lunch, w/ \"\"team\"\"\""), "CSV quotes/escapes comma in notes")
        expect(csv.contains("Chipotle,dining,12.34,USD,9876,no,manual"), "CSV row fields")
    }
}