import Foundation

struct MorningBrief: Identifiable, Codable {
    var id: String { date.description }
    let date: Date
    let yesterdayDeepWorkMinutes: Int
    let yesterdaySpend: Decimal
    let yesterdayTopCard: String?
    let upcomingRenewalNotice: String?
    let monthPacingStatus: PacingStatus
    let headline: String
}

enum MorningBriefingEngine {

    /// Generates a morning executive briefing based on yesterday's archives and live status.
    static func generateBrief(eventsYesterday: [TrackerEvent], subscriptions: SubscriptionSummary, pacing: SpendingPacing?) -> MorningBrief {
        var deepWorkMins = 0
        var spendYesterday: Decimal = 0
        var cardUsage: [String: Decimal] = [:]

        for e in eventsYesterday {
            if case .windowFocus(let w) = e.payload {
                let name = w.appName.lowercased()
                if name.contains("xcode") || name.contains("cursor") || name.contains("code") || name.contains("terminal") {
                    deepWorkMins += Int(w.durationSeconds / 60)
                }
            } else if case .receipt(let r) = e.payload {
                spendYesterday += r.amount
                let card = CardPortfolio.displayName(for: r.cardLast4)
                cardUsage[card, default: 0] += r.amount
            }
        }

        let topCard = cardUsage.max(by: { $0.value < $1.value })?.key

        var renewalMsg: String? = nil
        if let first = subscriptions.upcomingRenewals7Days.first {
            renewalMsg = "\(first.merchant) renews in \(first.daysUntilRenewal ?? 0)d (\(SpendFormat.amount(first.amount)))"
        }

        let pacingStatus = pacing?.pacingStatus ?? .onPace
        let hours = deepWorkMins / 60
        let mins = deepWorkMins % 60
        let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"

        let headline = "Yesterday: \(timeStr) focus · \(SpendFormat.amount(spendYesterday)) spend"

        return MorningBrief(
            date: Date(),
            yesterdayDeepWorkMinutes: deepWorkMins,
            yesterdaySpend: spendYesterday,
            yesterdayTopCard: topCard,
            upcomingRenewalNotice: renewalMsg,
            monthPacingStatus: pacingStatus,
            headline: headline
        )
    }
}
