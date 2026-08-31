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
        storage: StorageSnapshot = .empty,
        power: PowerSnapshot = .empty,
        renewals: [PredictedRenewal] = [],
        audioReport: AudioFlowReport = .empty,
        gitCommits: [GitCommitNode] = []
    ) -> CopilotResponse {
        let q = query.lowercased()

        // 1. Power & Battery queries
        if q.contains("battery") || q.contains("power") || q.contains("watts") || q.contains("wattage") || q.contains("runway") || q.contains("drain") || q.contains("charging") {
            let p = power.estimatedRemainingMinutes > 0 ? power : PowerPacingEngine.captureSnapshot()
            return CopilotResponse(
                title: "Apple Silicon Power Telemetry",
                answer: "Your Mac battery is at \(p.batteryPercent)%, \(p.narrative.lowercased()).",
                bulletPoints: [
                    "Battery Status: \(p.batteryPercent)% (\(p.runwayFormatted))",
                    "Estimated SoC Draw: ~\(String(format: "%.1f", p.estimatedWatts))W",
                    "Thermal State: \(p.thermalState)",
                    "Battery Cycle Count: \(p.cycleCount) cycles"
                ],
                actionPill: "View Power Telemetry"
            )
        }

        // 2. Git & Commit queries
        if q.contains("git") || q.contains("commit") || q.contains("branch") || q.contains("repo") || q.contains("shipped") || q.contains("code changes") {
            let commits = !gitCommits.isEmpty ? gitCommits : GitVelocityLinker.scanRecentCommits()
            let count = commits.count
            let latest = commits.first
            return CopilotResponse(
                title: "Git Commit & Output Velocity",
                answer: "You have shipped \(count) commits across local repositories today.",
                bulletPoints: [
                    "Latest Commit: \(latest?.repoName ?? "macsync") · \"\(latest?.message ?? "Initial commit")\"",
                    "Active Branch: \(latest?.branch ?? "main")",
                    "Hash: \(latest?.shortHash ?? "e1f03ad")",
                    "Total Repos Active: \(Set(commits.map { $0.repoName }).count)"
                ],
                actionPill: "Scrub in Time Machine"
            )
        }

        // 3. Subscription Renewals & Price Hikes
        if q.contains("renewal") || q.contains("renew") || q.contains("upcoming bill") || q.contains("next charge") || q.contains("subscription") || q.contains("hike") {
            let nextSub = renewals.first
            let imminentCount = renewals.filter { $0.isImminent }.count
            return CopilotResponse(
                title: "Subscription Renewal Radar",
                answer: "You have \(renewals.count) recurring subscriptions scheduled for renewal over the next 30 days.",
                bulletPoints: [
                    "Next Upcoming Charge: \(nextSub?.merchant ?? "None") (\(nextSub?.amountFormatted ?? "$0.00")) on \(nextSub?.renewalRelativeFormatted ?? "soon")",
                    "Imminent Renewals (<= 3 days): \(imminentCount) services",
                    "Monthly Recurring SaaS Total: \(SpendFormat.amount(spendMonth.byCategory[.software] ?? 0))",
                    "Price Hike Alerts: \(renewals.filter { $0.isPriceHike }.count) detected"
                ],
                actionPill: "Inspect Renewals"
            )
        }

        // 4. Music & Audio Flow correlation
        if q.contains("music") || q.contains("song") || q.contains("audio") || q.contains("spotify") || q.contains("soundtrack") || q.contains("flow") || q.contains("artist") {
            return CopilotResponse(
                title: "Soundtrack to Deep Work",
                answer: audioReport.summary,
                bulletPoints: [
                    "Top Productivity Audio: \(audioReport.topTracks.first?.title ?? "Ambient Flow")",
                    "Top Artist: \(audioReport.topArtist)",
                    "Typing Speed Boost: +\(audioReport.flowStateVelocityBoostPercent)% keystroke velocity",
                    "Correlated Focus Score: \(audioReport.topTracks.first?.avgFocusScore ?? 90)/100"
                ],
                actionPill: "View Flow Insights"
            )
        }

        // 5. Storage & iCloud Optimization queries
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

        // 6. Financial queries
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

        // 7. Tax / Schedule-C queries
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

        // 8. Work & Coding Output queries
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
                "Storage Status: \(storage.freeDiskFormatted) free · \(storage.reclaimableFormatted) offloadable to iCloud",
                "Apple Silicon Power: \(power.batteryPercent)% · \(power.runwayFormatted)"
            ],
            actionPill: nil
        )
    }
}
