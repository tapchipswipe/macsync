import Foundation

extension DataStore {
    /// Delete buffered JSONL files older than `days` (#6).
    func pruneBuffers(olderThan days: Int = 30) {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date())!
        var removed = 0
        for day in bufferedDays() {
            guard let date = SyncFormat.dayFormatter.date(from: day), date < cutoff else { continue }
            try? FileManager.default.removeItem(at: bufferFile(for: day))
            removed += 1
        }
        if removed > 0 { Log.store.info("Pruned \(removed) old buffer file(s)") }
    }

    /// Re-evaluates stored receipt events across buffer and archive directories,
    /// purging phantom non-purchases (brokerage trades, flight updates, $0 amounts,
    /// cloud budget alerts, and marketing newsletters).
    func pruneInvalidReceipts() {
        let dirs = [bufferDir, archiveDir]
        var totalPruned = 0

        for dir in dirs {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { continue }
            for name in files where name.hasPrefix("events-") && name.hasSuffix(".jsonl") {
                let fileURL = dir.appendingPathComponent(name)
                guard let data = try? Data(contentsOf: fileURL) else { continue }
                var keptLines: [Data] = []
                var modified = false

                data.split(separator: 0x0A).forEach { slice in
                    guard !slice.isEmpty else { return }
                    if let ev = try? SyncFormat.jsonDecoder.decode(TrackerEvent.self, from: Data(slice)),
                       case .receipt(let p) = ev.payload {
                        let merchantLC = p.merchant.lowercased()
                        let midLC = p.mailMessageID?.lowercased() ?? ""

                        let isBrokerage = merchantLC.contains("public") || midLC.contains("geopod")
                        let isDeltaPromo = merchantLC.contains("delta") && p.amount == Decimal(1787)
                        let isGoogleBudget = merchantLC == "google" && p.amount > 100 && (p.cardLast4 == nil || p.cardLast4?.isEmpty == true)
                        let isMarketing = ["turmerry", "panther technology", "bernie from planner5d", "northwestern mutual"].contains(merchantLC)
                        let isExcluded = merchantLC.contains("kart rising") || merchantLC.contains("steam") || midLC.contains("steampowered")
                        let isZeroOrNeg = p.amount <= 0

                        if isBrokerage || isDeltaPromo || isGoogleBudget || isMarketing || isExcluded || isZeroOrNeg {
                            modified = true
                            totalPruned += 1
                            return
                        }
                    }
                    keptLines.append(Data(slice))
                }

                if modified {
                    var out = Data()
                    for line in keptLines {
                        out.append(line)
                        out.append(0x0A)
                    }
                    try? out.write(to: fileURL, options: .atomic)
                }
            }
        }

        if totalPruned > 0 {
            Log.app.info("Pruned \(totalPruned) non-purchase receipt(s) from store")
        }
    }
}
