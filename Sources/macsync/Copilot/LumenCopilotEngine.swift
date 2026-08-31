import Foundation

struct CopilotResponse: Identifiable {
    let id = UUID()
    let title: String
    let answer: String
    let bulletPoints: [String]
    let actionPill: String?
}

enum LumenCopilotEngine {

    /// Answers natural language questions across the lifelog.
    static func ask(
        query: String,
        stats: TodayStats,
        spendMonth: SpendSummary,
        taxReport: ScheduleCTaxReport,
        forecast: FinancialForecast,
        storage: StorageSnapshot = .empty
    ) -> CopilotResponse {
        let q = query.lowercased()

        // 1. Storage & iCloud Optimization queries
        if q.contains("storage") || q.contains("space") || q.contains("disk") || q.contains("clean") || q.contains("icloud") || q.contains("offload") || q.contains("evict") {
            let s = storage.totalDiskBytes > 0 ? storage : iCloudStorageOptimizer.scanStorage()
            return CopilotResponse(
                title: "iCloud Storage Optimization",
                answer: "Your Mac has \(s.freeDiskFormatted) free of \(s.totalDiskFormatted) (\(Int(s.diskUsagePercentage))% capacity). You have \(s.reclaimableFormatted) ready to offload to iCloud.",
                bulletPoints: [
                    "iCloud Dataless Eviction: \(s.reclaimableFormatted) reclaimable at 0 bytes local footprint",
                    "iCloud Offloaded Content: \(s.iCloudEvictedFormatted) stored in cloud",
                    "Disposable Caches: \(ByteCountFormatter.string(fromByteCount: s.cachePurgeableBytes, countStyle: .file)) purgeable",
                    "Top Target: \(s.candidates.first?.title ?? "System Application Caches")"
                ],
                actionPill: "Optimize in Cloud"
            )
        }

        // 2. Financial queries
        if q.contains("spend") || q.contains("cost") || q.contains("card") || q.contains("steve") || q.contains("joyce") || q.contains("cava") {
            let total = spendMonth.total
            let topMerchant = spendMonth.byMerchant.max(by: { $0.value < $1.value })?.key ?? "Apple"
            let steveTotal = spendMonth.byCard["8031"] ?? 0
            let joyceTotal = spendMonth.byCard["1533"] ?? 0

            return CopilotResponse(
                title: "Financial Intelligence",
                answer: "You've spent \(SpendFormat.amount(total)) across all cards this month. Current projection is \(SpendFormat.amount(forecast.projectedMonthEndSpend)) by month-end.",
                bulletPoints: [
                    "Steve Credit (••8031): \(SpendFormat.amount(steveTotal))",
                    "Joyce Credit (••1533): \(SpendFormat.amount(joyceTotal))",
                    "Top Merchant: \(topMerchant)",
                    "Monthly Burn Rate: \(SpendFormat.amount(forecast.dailyBurnRate))/day"
                ],
                actionPill: "View Wallet"
            )
        }

        // 3. Tax / Schedule-C queries
        if q.contains("tax") || q.contains("deduct") || q.contains("schedule c") || q.contains("write off") {
            return CopilotResponse(
                title: "Tax & Schedule-C Strategy",
                answer: "You have \(SpendFormat.amount(taxReport.totalDeductibleAmount)) in verified business deductions mapped to IRS Schedule-C for 2026.",
                bulletPoints: [
                    "Line 18 (Software & SaaS): \(SpendFormat.amount(taxReport.byLine[.line18Software] ?? 0))",
                    "Line 22 (Supplies & Hardware): \(SpendFormat.amount(taxReport.byLine[.line22Supplies] ?? 0))",
                    "Line 24b (50% Business Meals): \(SpendFormat.amount(taxReport.byLine[.line24bMeals] ?? 0))",
                    "Estimated Cash Saved on Taxes (28%): \(SpendFormat.amount(forecast.estimatedTaxSavings))"
                ],
                actionPill: "Export Schedule-C CSV"
            )
        }

        // 4. Work & Coding Output queries
        if q.contains("work") || q.contains("code") || q.contains("built") || q.contains("focus") || q.contains("today") {
            let topApp = stats.apps.first?.name ?? "Xcode"
            return CopilotResponse(
                title: "Focus & Deep Work Summary",
                answer: "Today you logged \(Int(stats.activeMinutes)) minutes of active work with a Focus Score of \(stats.focusScore) (\(stats.focusScoreLabel)).",
                bulletPoints: [
                    "Top Project / App: \(topApp) (\(Int((stats.apps.first?.seconds ?? 0) / 60))m)",
                    "Keystrokes: \(stats.keystrokes) keys",
                    "Mouse Clicks: \(stats.clicks) clicks",
                    "Meeting Load: \(Int(stats.meetingMinutes))m"
                ],
                actionPill: "Open Dashboard"
            )
        }

        // Default Synthesis
        return CopilotResponse(
            title: "Lumen Intelligence Brief",
            answer: "Lumen is actively indexing your daily focus, card transactions, storage telemetry, and iCloud synchronization.",
            bulletPoints: [
                "Focus Score: \(stats.focusScore) · \(stats.focusScoreLabel)",
                "Month Spend: \(SpendFormat.amount(spendMonth.total)) · \(forecast.forecastNarrative)",
                "Storage Status: \(storage.freeDiskFormatted) free · \(storage.reclaimableFormatted) offloadable to iCloud"
            ],
            actionPill: nil
        )
    }
}
