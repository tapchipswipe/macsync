import Foundation

/// Shared money/date formatting for the spending UI.
enum SpendFormat {
    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static func amount(_ value: Decimal) -> String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    static func amount(_ value: Decimal, currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: NSDecimalNumber(decimal: value)) ?? String(describing: value)
    }

    static func monthTitle(offset: Int = 0) -> String {
        let cal = Calendar.current
        let now = Date()
        let target = cal.date(byAdding: .month, value: offset, to: now) ?? now
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: target).uppercased()
    }

    static func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: d)
    }
}