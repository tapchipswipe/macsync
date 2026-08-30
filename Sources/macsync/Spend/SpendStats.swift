import Foundation

/// Aggregated spending view over a set of receipt events (a month, a week,
/// today). Pure math — unit-testable without any collector.
struct SpendSummary {
    var receipts: [ReceiptPayload] = []              // sorted newest-first
    var total: Decimal = 0
    var deductibleTotal: Decimal = 0                 // category defaultdeductible
    var byCategory: [ReceiptCategory: Decimal] = [:]
    var byCard: [String: Decimal] = [:]              // "1234" | "Unknown"
    var byMerchant: [String: Decimal] = [:]
    var needsReviewCount = 0

    static let empty = SpendSummary()
}

enum SpendStats {

    /// Rollup for the month containing `monthOffset` months from now
    /// (0 = current month, -1 = last month).
    static func calculate(events: [TrackerEvent]) -> SpendSummary {
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
        return s
    }

    /// All receipt events whose transaction date lands in the month of
    /// `monthOffset` (0 = current). Combines today's buffer with archives.
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
        // Generalize: past synced days live in the archive dir.
        let archived = HistoryLoader.archivedEvents(daysBack: 62)
        for (_, evs) in archived {
            events += evs.filter { e in
                guard case .receipt(let p) = e.payload else { return false }
                return p.transactionDate >= targetStart && p.transactionDate < targetEnd
            }
        }
        return events
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