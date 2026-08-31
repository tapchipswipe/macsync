import Foundation

struct ZombieSubscriptionAlert: Identifiable, Codable {
    var id: String { merchant.lowercased() }
    let merchant: String
    let monthlyAmount: Decimal
    let annualizedAmount: Decimal
    let totalUsageMinutes: Int
    let associatedAppName: String
    let recommendation: String
}

enum ZombieDetector {

    /// Known subscription-to-macOS app mappings.
    private static let appBindings: [String: String] = [
        "adobe": "Adobe Creative Cloud",
        "figma": "Figma",
        "notion": "Notion",
        "github": "GitHub Desktop",
        "microsoft": "Microsoft Word",
        "spotify": "Spotify",
        "apple": "Music",
        "slack": "Slack",
        "linear": "Linear",
        "cursor": "Cursor"
    ]

    /// Detects subscriptions where 30-day usage is less than 20 minutes.
    static func detectZombies(subscriptions: [TrackedSubscription], appUsage30Days: [String: TimeInterval]) -> [ZombieSubscriptionAlert] {
        var alerts: [ZombieSubscriptionAlert] = []

        for sub in subscriptions {
            let key = sub.merchant.lowercased()
            guard let appName = appBindings.first(where: { key.contains($0.key) })?.value else {
                continue
            }

            let usageSeconds = appUsage30Days[appName] ?? 0
            let usageMins = Int(usageSeconds / 60)

            if usageMins < 20 {
                let alert = ZombieSubscriptionAlert(
                    merchant: sub.merchant,
                    monthlyAmount: sub.monthlyAmount,
                    annualizedAmount: sub.annualizedAmount,
                    totalUsageMinutes: usageMins,
                    associatedAppName: appName,
                    recommendation: "You only used \(appName) for \(usageMins)m this month while paying \(SpendFormat.amount(sub.monthlyAmount))/mo (\(SpendFormat.amount(sub.annualizedAmount))/yr)."
                )
                alerts.append(alert)
            }
        }

        return alerts
    }
}
