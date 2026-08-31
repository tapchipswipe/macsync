import Foundation

enum SearchResultCategory: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case spend = "Purchases & Finance"
    case codeAndApps = "Projects & Deep Work"
    case browsing = "Web Research"
    case workspace = "Locations & Networks"

    var icon: String {
        switch self {
        case .spend: return "creditcard.fill"
        case .codeAndApps: return "sparkles"
        case .browsing: return "safari.fill"
        case .workspace: return "network"
        }
    }
}

struct SearchResultItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let date: Date
    let category: SearchResultCategory
    let icon: String
    let colorHex: String
    let badge: String?
    let amount: Decimal?
    let payloadRef: Any?
}

enum LifelogSearchEngine {

    /// Searches across the active buffer and 365 days of archives using natural-language matching.
    static func search(query: String, maxResultsPerCategory: Int = 8) -> [SearchResultCategory: [SearchResultItem]] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return [:] }

        var results: [SearchResultCategory: [SearchResultItem]] = [:]
        for cat in SearchResultCategory.allCases {
            results[cat] = []
        }

        // Pull events from buffer and archive
        var allEvents: [TrackerEvent] = []
        for day in DataStore.shared.bufferedDays() {
            allEvents += DataStore.shared.events(forDay: day)
        }
        for (_, archived) in HistoryLoader.archivedEvents(daysBack: 366) {
            allEvents += archived
        }

        // Search Receipts
        var seenReceiptIDs = Set<UUID>()
        for e in allEvents {
            guard case .receipt(let r) = e.payload else { continue }
            if seenReceiptIDs.contains(r.id) { continue }

            let cardName = CardPortfolio.displayName(for: r.cardLast4).lowercased()
            let shortCard = CardPortfolio.shortName(for: r.cardLast4).lowercased()
            let merchantMatch = r.merchant.lowercased().contains(clean)
            let categoryMatch = r.category.label.lowercased().contains(clean)
            let cardMatch = (r.cardLast4?.contains(clean) ?? false) || cardName.contains(clean) || shortCard.contains(clean)
            let notesMatch = (r.notes?.lowercased().contains(clean) ?? false)

            if merchantMatch || categoryMatch || cardMatch || notesMatch {
                seenReceiptIDs.insert(r.id)
                let item = SearchResultItem(
                    id: r.id,
                    title: "\(r.merchant) · \(SpendFormat.amount(r.amount, currency: r.currency))",
                    subtitle: "\(SpendFormat.shortDate(r.transactionDate)) · \(CardPortfolio.displayName(for: r.cardLast4))\(r.notes != nil ? " (\(r.notes!))" : "")",
                    date: r.transactionDate,
                    category: .spend,
                    icon: r.category.icon,
                    colorHex: r.category.colorHex,
                    badge: CardPortfolio.shortName(for: r.cardLast4),
                    amount: r.amount,
                    payloadRef: r
                )
                results[.spend]?.append(item)
            }
        }

        // Search Window Titles and Projects
        var seenTitles = Set<String>()
        for e in allEvents {
            if case .windowFocus(let w) = e.payload {
                guard let title = w.windowTitle, !title.isEmpty else { continue }
                if seenTitles.contains(title) { continue }

                if title.lowercased().contains(clean) || w.appName.lowercased().contains(clean) {
                    seenTitles.insert(title)
                    let isCode = w.appName.lowercased().contains("xcode") || w.appName.lowercased().contains("cursor") || w.appName.lowercased().contains("terminal")
                    let item = SearchResultItem(
                        id: UUID(),
                        title: title,
                        subtitle: "\(w.appName) · \(SpendFormat.shortDate(e.ts))",
                        date: e.ts,
                        category: isCode ? .codeAndApps : .browsing,
                        icon: isCode ? "hammer.fill" : "safari.fill",
                        colorHex: isCode ? "#5B8CFF" : "#A78BFA",
                        badge: w.appName,
                        amount: nil,
                        payloadRef: w
                    )
                    let targetCat: SearchResultCategory = isCode ? .codeAndApps : .browsing
                    results[targetCat]?.append(item)
                }
            } else if case .networkContext(let net) = e.payload {
                if let ssid = net.ssid, ssid.lowercased().contains(clean) {
                    if !seenTitles.contains(ssid) {
                        seenTitles.insert(ssid)
                        let item = SearchResultItem(
                            id: UUID(),
                            title: ssid,
                            subtitle: "Wi-Fi Network · Seen on \(SpendFormat.shortDate(e.ts))",
                            date: e.ts,
                            category: .workspace,
                            icon: "wifi",
                            colorHex: "#63E6BE",
                            badge: "Network",
                            amount: nil,
                            payloadRef: net
                        )
                        results[.workspace]?.append(item)
                    }
                }
            }
        }

        // Trim to max results and sort newest first
        for cat in SearchResultCategory.allCases {
            if var items = results[cat] {
                items.sort { $0.date > $1.date }
                results[cat] = Array(items.prefix(maxResultsPerCategory))
            }
        }

        return results
    }
}
