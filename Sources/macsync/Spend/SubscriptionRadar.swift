import Foundation

enum BillingCadence: String, Codable, CaseIterable {
    case monthly, annual, weekly, usageBased

    var label: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .weekly: return "Weekly"
        case .usageBased: return "Usage-based"
        }
    }
}

struct TrackedSubscription: Identifiable, Codable {
    var id: String { "\(merchant.lowercased())_\(cardLast4 ?? "direct")" }
    let merchant: String
    let amount: Decimal
    let currency: String
    let cadence: BillingCadence
    let cardLast4: String?
    let category: ReceiptCategory
    let lastBilledDate: Date
    let nextRenewalDate: Date?
    let usageSeconds30d: TimeInterval?

    var annualizedAmount: Decimal {
        switch cadence {
        case .monthly: return amount * 12
        case .annual: return amount
        case .weekly: return amount * 52
        case .usageBased: return amount * 12
        }
    }

    var monthlyAmount: Decimal {
        switch cadence {
        case .monthly: return amount
        case .annual: return amount / 12
        case .weekly: return amount * 4.33
        case .usageBased: return amount
        }
    }

    /// Zombie Subscription: A software/tool subscription where app focus is < 30 minutes across 30 days.
    var isZombie: Bool {
        guard category == .software || category == .subscriptions else { return false }
        if let sec = usageSeconds30d {
            return sec < 1800 // Less than 30 minutes
        }
        return false
    }

    /// Days remaining until next renewal.
    var daysUntilRenewal: Int? {
        guard let next = nextRenewalDate else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0
        return max(0, diff)
    }
}

struct SubscriptionSummary {
    let activeSubscriptions: [TrackedSubscription]
    let monthlyBurnRate: Decimal
    let annualBurnRate: Decimal
    let upcomingRenewals7Days: [TrackedSubscription]
    let zombieSubscriptions: [TrackedSubscription]

    static let empty = SubscriptionSummary(
        activeSubscriptions: [],
        monthlyBurnRate: 0,
        annualBurnRate: 0,
        upcomingRenewals7Days: [],
        zombieSubscriptions: []
    )
}

enum SubscriptionRadar {

    /// Known recurring software, cloud, and entertainment subscription vendors.
    private static let knownVendors: [String: (cadence: BillingCadence, category: ReceiptCategory, appName: String?)] = [
        "apple": (.monthly, .subscriptions, "Music"),
        "netflix": (.monthly, .subscriptions, nil),
        "spotify": (.monthly, .subscriptions, "Spotify"),
        "hulu": (.monthly, .subscriptions, nil),
        "disney+": (.monthly, .subscriptions, nil),
        "youtube premium": (.monthly, .subscriptions, nil),
        "amazon prime": (.annual, .subscriptions, nil),
        "adobe": (.monthly, .software, "Adobe Creative Cloud"),
        "figma": (.monthly, .software, "Figma"),
        "github": (.monthly, .software, "GitHub Desktop"),
        "notion": (.monthly, .software, "Notion"),
        "microsoft": (.monthly, .software, "Microsoft Word"),
        "retell": (.usageBased, .software, nil),
        "cline": (.usageBased, .software, "Cursor"),
        "google workspace": (.monthly, .software, "Google Chrome")
    ]

    /// Analyzes all tracked receipts and extracts active recurring subscriptions.
    static func analyze(receipts: [ReceiptPayload], appUsage: [String: TimeInterval] = [:]) -> SubscriptionSummary {
        var grouped: [String: [ReceiptPayload]] = [:]
        for r in receipts {
            let key = r.merchant.lowercased()
            grouped[key, default: []].append(r)
        }

        var subs: [TrackedSubscription] = []

        for (merchantKey, group) in grouped {
            let sorted = group.sorted { $0.transactionDate > $1.transactionDate }
            guard let newest = sorted.first else { continue }

            var detectedCadence: BillingCadence? = nil
            var matchedAppName: String? = nil

            // 1. Check known vendor rules
            for (vendor, info) in knownVendors {
                if merchantKey.contains(vendor) {
                    detectedCadence = info.cadence
                    matchedAppName = info.appName
                    break
                }
            }

            // 2. Multi-transaction periodicity detection (e.g. 25-35 days apart = monthly)
            if detectedCadence == nil && sorted.count >= 2 {
                let d1 = sorted[0].transactionDate
                let d2 = sorted[1].transactionDate
                let days = abs(Calendar.current.dateComponents([.day], from: d2, to: d1).day ?? 0)
                if days >= 25 && days <= 35 {
                    detectedCadence = .monthly
                } else if days >= 350 && days <= 380 {
                    detectedCadence = .annual
                } else if days >= 6 && days <= 8 {
                    detectedCadence = .weekly
                }
            }

            // 3. If explicit category is subscriptions, treat as monthly by default
            if detectedCadence == nil && newest.category == .subscriptions {
                detectedCadence = .monthly
            }

            guard let cadence = detectedCadence else { continue }

            // Project next renewal date
            let cal = Calendar.current
            var nextDate: Date? = nil
            switch cadence {
            case .monthly, .usageBased:
                nextDate = cal.date(byAdding: .month, value: 1, to: newest.transactionDate)
            case .annual:
                nextDate = cal.date(byAdding: .year, value: 1, to: newest.transactionDate)
            case .weekly:
                nextDate = cal.date(byAdding: .day, value: 7, to: newest.transactionDate)
            }

            // App usage seconds lookup if available
            var usage: TimeInterval? = nil
            if let app = matchedAppName, let sec = appUsage[app] {
                usage = sec
            }

            let sub = TrackedSubscription(
                merchant: newest.merchant,
                amount: newest.amount,
                currency: newest.currency,
                cadence: cadence,
                cardLast4: newest.cardLast4,
                category: newest.category,
                lastBilledDate: newest.transactionDate,
                nextRenewalDate: nextDate,
                usageSeconds30d: usage
            )
            subs.append(sub)
        }

        subs.sort { ($0.daysUntilRenewal ?? 999) < ($1.daysUntilRenewal ?? 999) }

        let monthlyTotal = subs.reduce(Decimal.zero) { $0 + $1.monthlyAmount }
        let annualTotal = subs.reduce(Decimal.zero) { $0 + $1.annualizedAmount }
        let upcoming = subs.filter { ($0.daysUntilRenewal ?? 999) <= 7 }
        let zombies = subs.filter { $0.isZombie }

        return SubscriptionSummary(
            activeSubscriptions: subs,
            monthlyBurnRate: monthlyTotal,
            annualBurnRate: annualTotal,
            upcomingRenewals7Days: upcoming,
            zombieSubscriptions: zombies
        )
    }
}
