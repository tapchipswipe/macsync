import Foundation

struct PredictedRenewal: Identifiable, Codable {
    let id: UUID
    let merchant: String
    let amount: Decimal
    let lastBilledDate: Date
    let nextBillingDate: Date
    let daysUntilRenewal: Int
    let isImminent: Bool
    let isPriceHike: Bool
    let priceHikeDifference: Decimal

    init(id: UUID = UUID(), merchant: String, amount: Decimal, lastBilledDate: Date, nextBillingDate: Date, isPriceHike: Bool = false, priceHikeDifference: Decimal = 0) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.lastBilledDate = lastBilledDate
        self.nextBillingDate = nextBillingDate
        self.isPriceHike = isPriceHike
        self.priceHikeDifference = priceHikeDifference

        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfTarget = cal.startOfDay(for: nextBillingDate)
        let diff = cal.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
        self.daysUntilRenewal = max(0, diff)
        self.isImminent = (diff >= 0 && diff <= 3)
    }

    var amountFormatted: String {
        SpendFormat.amount(amount)
    }

    var renewalRelativeFormatted: String {
        if daysUntilRenewal == 0 { return "Renews today" }
        if daysUntilRenewal == 1 { return "Renews tomorrow" }
        return "Renews in \(daysUntilRenewal) days"
    }
}

enum SubscriptionRenewalCalendar {

    static func forecastRenewals(subscriptions: [TrackedSubscription], receipts: [ReceiptPayload] = []) -> [PredictedRenewal] {
        let cal = Calendar.current
        var results: [PredictedRenewal] = []

        for sub in subscriptions {
            // Find all receipts matching this merchant
            let matchingReceipts = receipts.filter {
                $0.merchant.localizedCaseInsensitiveContains(sub.merchant) ||
                sub.merchant.localizedCaseInsensitiveContains($0.merchant)
            }.sorted(by: { $0.transactionDate > $1.transactionDate })

            let latestReceiptDate = matchingReceipts.first?.transactionDate ?? sub.lastBilledDate
            let latestAmount = matchingReceipts.first?.amount ?? sub.monthlyAmount

            // Calculate next billing date (e.g. +1 month from latest receipt)
            var nextDate = latestReceiptDate
            while nextDate <= Date() {
                if let advanced = cal.date(byAdding: .month, value: 1, to: nextDate) {
                    nextDate = advanced
                } else {
                    break
                }
            }

            // Check for price hike
            var priceHike = false
            var hikeDiff: Decimal = 0
            if matchingReceipts.count >= 2 {
                let currentCharge: Decimal = matchingReceipts[0].amount
                let priorCharge: Decimal = matchingReceipts[1].amount
                if currentCharge > priorCharge {
                    priceHike = true
                    hikeDiff = currentCharge - priorCharge
                }
            }

            results.append(PredictedRenewal(
                merchant: sub.merchant,
                amount: latestAmount,
                lastBilledDate: latestReceiptDate,
                nextBillingDate: nextDate,
                isPriceHike: priceHike,
                priceHikeDifference: hikeDiff
            ))
        }

        return results.sorted(by: { $0.nextBillingDate < $1.nextBillingDate })
    }
}
