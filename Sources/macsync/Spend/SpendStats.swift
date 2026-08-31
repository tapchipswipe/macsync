import Foundation

enum PacingStatus: String, Codable {
    case belowAverage = "Below Average"
    case onPace = "On Pace"
    case elevated = "Elevated"

    var colorHex: String {
        switch self {
        case .belowAverage: return "#63E6BE" // Green
        case .onPace: return "#5B8CFF"       // Blue
        case .elevated: return "#FF6B8A"     // Coral / Red
        }
    }
}

struct SpendingPacing {
    let daysElapsed: Int
    let totalDaysInMonth: Int
    let dailyBurnRate: Decimal
    let projectedMonthEndTotal: Decimal
    let baselineMonthlyAverage: Decimal
    let pacingStatus: PacingStatus

    static let baseline2026: Decimal = Decimal(string: "350.39") ?? 350
}

/// Aggregated spending view over a set of receipt events (a month, a week,
/// today). Pure math — unit-testable without any collector.
struct SpendSummary {
    var receipts: [ReceiptPayload] = []              // sorted newest-first
    var total: Decimal = 0
    var deductibleTotal: Decimal = 0                 // category default deductible
    var byCategory: [ReceiptCategory: Decimal] = [:]
    var byCard: [String: Decimal] = [:]              // "8031" | "1533" | "Direct"
    var byMerchant: [String: Decimal] = [:]
    var needsReviewCount = 0
    var pacing: SpendingPacing? = nil

    static let empty = SpendSummary()
}

enum SpendStats {

    /// Rollup for the month containing `monthOffset` months from now
    /// (0 = current month, -1 = last month, -2 = 2 months ago, etc.).
    static func calculate(events: [TrackerEvent], monthOffset: Int = 0) -> SpendSummary {
        var s = SpendSummary()
        for e in events {
            guard case .receipt(let p) = e.payload else { continue }
            s.receipts.append(p)
            s.total += p.amount
            if p.category.businessDeductible { s.deductibleTotal += p.amount }
            s.byCategory[p.category, default: 0] += p.amount
            s.byCard[p.cardLast4 ?? "Unknown", default: 0] += p.amount
            s.byMerchant[p.merchant, default: 0] += p.amount
            if p.needsReview { s.needsReviewCount += 1 }
        }
        s.receipts.sort { $0.transactionDate > $1.transactionDate }

        // Calculate Spending Pacing
        let cal = Calendar.current
        let now = Date()
        guard let targetDate = cal.date(byAdding: .month, value: monthOffset, to: now),
              let range = cal.range(of: .day, in: .month, for: targetDate) else {
            return s
        }

        let totalDays = range.count
        let dayOfMonth = (monthOffset == 0) ? cal.component(.day, from: now) : totalDays
        let daysElapsed = max(1, dayOfMonth)

        let dailyRate = s.total / Decimal(daysElapsed)
        let projected = dailyRate * Decimal(totalDays)

        let baseline = SpendingPacing.baseline2026
        let status: PacingStatus
        if projected < baseline * Decimal(string: "0.85")! {
            status = .belowAverage
        } else if projected > baseline * Decimal(string: "1.25")! {
            status = .elevated
        } else {
            status = .onPace
        }

        s.pacing = SpendingPacing(
            daysElapsed: daysElapsed,
            totalDaysInMonth: totalDays,
            dailyBurnRate: dailyRate,
            projectedMonthEndTotal: projected,
            baselineMonthlyAverage: baseline,
            pacingStatus: status
        )

        return s
    }

    /// All receipt events whose transaction date lands in the month of
    /// `monthOffset` (0 = current). Combines today's buffer with archives across 365 days.
    static func eventsForMonth(monthOffset: Int = 0) -> [TrackerEvent] {
        let cal = Calendar.current
        let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let target = cal.date(byAdding: .month, value: monthOffset, to: monthStart),
              let targetStart = cal.date(from: cal.dateComponents([.year, .month], from: target)),
              let targetEnd = cal.date(byAdding: .month, value: 1, to: targetStart) else { return [] }

        var events: [TrackerEvent] = []
        for day in DataStore.shared.bufferedDays() {
            guard let d = SyncFormat.dayFormatter.date(from: day) else { continue }
            if d >= targetStart && d < targetEnd {
                events += DataStore.shared.events(forDay: day)
            }
        }
        // Past synced days in archive directory across 365 days
        let archived = HistoryLoader.archivedEvents(daysBack: 366)
        for (_, evs) in archived {
            events += evs.filter { e in
                guard case .receipt(let p) = e.payload else { return false }
                return p.transactionDate >= targetStart && p.transactionDate < targetEnd
            }
        }
        return events
    }

    /// Month title for display (e.g. "August 2026" or "July 2026").
    static func monthTitle(for monthOffset: Int = 0) -> String {
        let cal = Calendar.current
        let now = Date()
        guard let target = cal.date(byAdding: .month, value: monthOffset, to: now) else { return "This Month" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: target)
    }

    /// Today's receipt events (live buffer).
    static func eventsForToday() -> [TrackerEvent] {
        DataStore.shared.events(forDay: SyncFormat.dayString())
            .filter { if case .receipt = $0.payload { return true } else { return false } }
    }

    /// All tracked receipts across the buffer and ~1 year of archives,
    /// newest first — used for CSV/JSON export.
    static func allReceipts() -> [ReceiptPayload] {
        var events: [TrackerEvent] = []
        for day in DataStore.shared.bufferedDays() {
            events += DataStore.shared.events(forDay: day)
        }
        for (_, archived) in HistoryLoader.archivedEvents(daysBack: 366) {
            events += archived
        }
        return events.compactMap { if case .receipt(let p) = $0.payload { return p } else { return nil } }
            .sorted { $0.transactionDate > $1.transactionDate }
    }
}
