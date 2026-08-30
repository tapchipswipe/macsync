import Foundation

enum ReceiptParserTests {
    static func run() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)

        // ── Declined / failed payments are NEVER receipts ──
        expect(ReceiptParser.looksLikeFailedPayment(
            subject: "Transaction decline notification", sender: "Team Privacy <support@privacy.com>"),
            "Privacy.com decline subject → failed payment")
        expect(ReceiptParser.looksLikeFailedPayment(
            subject: "$142.00 payment to Flux.ai was unsuccessful again", sender: "Flux.ai <failed-payments@flux.ai>"),
            "unsuccessful payment subject → failed payment")
        expect(ReceiptParser.looksLikeFailedPayment(
            subject: "$49.99 payment to Planner5D, UAB was unsuccessful again", sender: "\"Planner5D, UAB\" <failed-payments+acct@stripe.com>"),
            "stripe failed-payments sender → failed payment")
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "Transaction decline notification", sender: "Team Privacy <support@privacy.com>"),
            "declined transaction excluded from receipts")
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "$49.99 payment to Planner5D, UAB was unsuccessful again", sender: "x <failed-payments@stripe.com>"),
            "unsuccessful payment excluded from receipts")

        // ── Brokerage / Investment / Trading rejections ──
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "Your trade has been executed", sender: "Public <support@public.com>"),
            "Public trade subject excluded in pass A")
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "Order filled: Buy 10 AAPL", sender: "Robinhood <support@robinhood.com>"),
            "Robinhood order filled excluded in pass A")
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "Your recurring crypto buy of $50.00 was completed", sender: "Coinbase <no-reply@coinbase.com>"),
            "Coinbase crypto buy excluded in pass A")

        let publicTrade = ReceiptParser.parse(
            subject: "Your trade has been executed",
            sender: "Public <no-reply@geopod-ismtpd-37>",
            body: "Your market order to buy $37.67 of VOO has been executed.\nShares: 0.072\nPrice: $520.12",
            sentDate: d)
        expect(publicTrade.amount == nil, "Public.com trade parsed as non-purchase (amount nil)")

        let robinhood = ReceiptParser.parse(
            subject: "Trade confirmation",
            sender: "Robinhood Financial <orders@robinhood.com>",
            body: "You bought 5 shares of NVDA for $650.00.\nTotal: $650.00",
            sentDate: d)
        expect(robinhood.amount == nil, "Robinhood trade confirmation rejected")

        // ── Travel / Airline: Flight updates & SkyMiles vs Real Ticket Receipts ──
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "Time to check in for your flight DL 1787 to Atlanta", sender: "Delta Air Lines <ticketreceipt@delta.com>"),
            "Delta check-in alert excluded in pass A")
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "Your SkyMiles summary: 1,787 Medallion miles earned", sender: "Delta Air Lines <news@delta.com>"),
            "Delta SkyMiles points statement excluded in pass A")

        let deltaCheckIn = ReceiptParser.parse(
            subject: "Flight DL 1787 update: On time",
            sender: "Delta Air Lines <notifications@delta.com>",
            body: "Your upcoming flight DL 1787 to Atlanta is on schedule.\nUpgrade to First Class from $1,787.00.",
            sentDate: d)
        expect(deltaCheckIn.amount == nil, "Delta flight update / upgrade promo rejected")

        let deltaRealReceipt = ReceiptParser.parse(
            subject: "Your Flight Receipt - Passenger Receipt and Itinerary",
            sender: "Delta Air Lines <ticketreceipt@delta.com>",
            body: "Thank you for choosing Delta.\nTicket Number: 0062384910293\nTotal Amount Charged: $340.50\nPayment Method: Visa ending in 4417",
            sentDate: d)
        expect(deltaRealReceipt.amount == Decimal(string: "340.50"), "Real Delta ticket receipt parsed")
        expect(deltaRealReceipt.merchant == "Delta Air Lines", "Delta merchant recognized")
        expect(deltaRealReceipt.cardLast4 == "4417", "Delta receipt card last4")
        expect(!deltaRealReceipt.needsReview, "Delta real receipt high confidence")

        // ── Cloud / SaaS Budget Alerts vs Real Invoices ──
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "Google Cloud Budget Alert: 100% of your $500 budget reached", sender: "Google Cloud Billing <billing@google.com>"),
            "Google Cloud budget alert excluded in pass A")

        let googleBudget = ReceiptParser.parse(
            subject: "Google Cloud billing alert",
            sender: "Google <google-cloud-billing@google.com>",
            body: "Your Cloud billing account has exceeded 100% of budget.\nEstimated charges: $541.00 for August.",
            sentDate: d)
        expect(googleBudget.amount == nil, "Google Cloud budget alert rejected")

        let googleRealInvoice = ReceiptParser.parse(
            subject: "Your Google Workspace invoice is ready",
            sender: "Google Workspace <payments-noreply@google.com>",
            body: "Invoice Number: GOOG-123456\nTotal paid: $14.40\nCharged to Mastercard ending in 9012",
            sentDate: d)
        expect(googleRealInvoice.amount == Decimal(string: "14.40"), "Real Google invoice parsed")
        expect(googleRealInvoice.merchant == "Google", "Google merchant recognized")

        // ── Bank Transfers / Credit Card Payments ──
        expect(!ReceiptParser.looksLikeReceipt(
            subject: "Your credit card payment of $1,200.00 has posted", sender: "Chase <no-reply@chase.com>"),
            "Credit card bill payment excluded in pass A")

        let ccPayment = ReceiptParser.parse(
            subject: "Payment received - thank you",
            sender: "Chase Card Services <notifications@chase.com>",
            body: "We received your payment of $1,200.00 to your card ending in 5543 on Aug 28, 2026.",
            sentDate: d)
        expect(ccPayment.amount == nil, "Credit card debt payment rejected as non-purchase")

        // ── Shopify billing: "bill for {X}" ──
        let shopify = ReceiptParser.parse(
            subject: "Aug 13, 2026 bill for Kart Rising LLC",
            sender: "Shopify Billing <billing@shopify.com>",
            body: "Your bill for this period.\nTotal: $39.00\nCharged to Visa ending in 4417",
            sentDate: d)
        expect(shopify.merchant == "Kart Rising LLC", "Shopify 'bill for' merchant extraction")
        expect(shopify.amount == Decimal(string: "39.00"), "Shopify bill total")
        expect(!shopify.needsReview, "Shopify bill high confidence")

        // ── Swell Labs: "Order #X confirmed" (unknown sender, display-name fallback) ──
        expect(ReceiptParser.looksLikeReceipt(
            subject: "Order #955890 confirmed", sender: "Swell Labs <hi@swelllabs.org>"),
            "order-confirmed subject is a receipt candidate")
        let swell = ReceiptParser.parse(
            subject: "Order #955890 confirmed",
            sender: "Swell Labs <hi@swelllabs.org>",
            body: "Thanks for your order!\nOrder total: $64.00\nPaid with Mastercard ending in 8812",
            sentDate: d)
        expect(swell.merchant == nil, "unknown sender → merchant nil (collector falls back to display name)")
        expect(swell.amount == Decimal(string: "64.00"), "Swell Labs order total")

        // ── Venmo P2P: "You paid {Person} $X" ──
        let venmo = ReceiptParser.parse(
            subject: "You paid Jackson Wainwright $8.00",
            sender: "Venmo <venmo@venmo.com>",
            body: "You paid Jackson Wainwright $8.00.",
            sentDate: d)
        expect(venmo.merchant == "Jackson Wainwright", "Venmo P2P payee as merchant")
        expect(venmo.amount == Decimal(string: "8.00"), "Venmo amount")

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
        expect(skimpy.amount == Decimal(string: "19.99"), "bare $ amount parsed with you paid context")
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

        // ── Non-transaction rejections ──
        // $0 amount is never a real purchase
        let zeroAmount = ReceiptParser.parse(
            subject: "Receipt", sender: "receipt@example.com",
            body: "Total: $0.00", sentDate: d)
        expect(zeroAmount.amount == nil, "zero amount rejected → nil")

        // Klaviyo marketing email with dollar amount, no purchase language in subject
        let klaviyo = ReceiptParser.parse(
            subject: "Your weekly recap", sender: "Klaviyo <hello@klaviyomail.com>",
            body: "This week you saved $12.99 on Turmerry sheets", sentDate: d)
        expect(klaviyo.amount == nil, "klaviyo marketing email rejected")

        // Sender-sib (Brevo) notification with dollar amount
        let brevo = ReceiptParser.parse(
            subject: "Account notification", sender: "Panther <no-reply@hl.d.sender-sib.com>",
            body: "Your plan balance: $20.00", sentDate: d)
        expect(brevo.amount == nil, "brevo notification rejected")

        // Declined charge in body even if subject says "receipt"
        let declined = ReceiptParser.parse(
            subject: "Receipt", sender: "Flux.ai <support@flux.ai>",
            body: "Your payment of $5.99 was declined. Card ending in 2654.", sentDate: d)
        expect(declined.amount == nil, "declined charge rejected")

        // But a real order from an ESP domain passes if subject says "order"
        let realOrder = ReceiptParser.parse(
            subject: "Order #123 confirmed", sender: "Swell Labs <hi@swelllabs.org>",
            body: "Order total: $64.00\nPaid with Visa ending in 8812", sentDate: d)
        expect(realOrder.amount == Decimal(string: "64.00"), "real order from ESP domain passes")
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
