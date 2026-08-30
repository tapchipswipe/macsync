import AppKit
import Foundation

/// Scans Apple Mail for receipt-like messages and emits `ReceiptPayload`
/// events into the same buffer as every other collector.
///
/// Privacy: **off by default** (`macsync.receiptCaptureEnabled`). Pass A lists
/// recent message ids + subjects/senders only; pass B fetches bodies **only**
/// for ids whose subject/sender already matched
/// `ReceiptParser.looksLikeReceipt`. Only parsed fields are stored — never raw
/// content. Dedup by message id keeps the scan idempotent across polls/restarts.
final class ReceiptMailCollector {
    private let store = DataStore.shared
    private let queue = DispatchQueue(label: "com.macsync.receipts", qos: .utility)
    private var timer: DispatchSourceTimer?

    private let pollInterval: TimeInterval = 30 * 60   // every 30 minutes
    private let maxCandidates = 400                    // cap pass A size

    // MARK: - Lifecycle

    func start() {
        stop()
        guard SpendOptions.captureEnabled else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        // First scan shortly after launch (backfills recent window), then every 30 min.
        timer.schedule(deadline: .now() + 15, repeating: pollInterval)
        timer.setEventHandler { [weak self] in self?.scan() }
        timer.resume()
        self.timer = timer
        // Also run one immediate scan so we don't wait 15s on first enable.
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in self?.scan() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Scan

    private func scan() {
        guard SpendOptions.captureEnabled else { Log.app.error("receipt scan skipped: capture disabled"); return }
        // Never force-launch Mail just to scan it.
        let running = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.mail" }
        guard running else { Log.app.error("receipt scan skipped: Mail not running"); return }

        let processed = processedMessageIDs
        Log.app.error("receipt scan starting, \(processed.count) already processed")
        guard let candidates = listCandidates() else { Log.app.error("receipt scan: listCandidates returned nil"); return }
        Log.app.error("receipt scan: \(candidates.count) candidates after filtering, \(candidates.filter { !processed.contains($0.id) }.count) fresh")
        let fresh = candidates.filter { !processed.contains($0.id) }
        guard !fresh.isEmpty else { return }

        // Fetch bodies only for the shortlist, then parse + store.
        let details = fetchDetails(ids: fresh.map(\.id))
        for detail in details {
            let parsed = ReceiptParser.parse(subject: detail.subject, sender: detail.sender,
                                             body: detail.body, sentDate: detail.date)
            guard let amount = parsed.amount else {
                // No amount → not a real purchase; don't record.
                Log.app.error("receipt skipped (no amount): \(detail.subject.prefix(60))")
                continue
            }
            let merchant = parsed.merchant ?? Self.merchantGuess(from: detail.sender)
            let payload = ReceiptPayload(
                id: UUID(),
                merchant: merchant,
                amount: amount,
                currency: parsed.currency ?? "USD",
                cardLast4: parsed.cardLast4,
                category: ReceiptCategorizer.category(for: merchant),
                transactionDate: parsed.transactionDate ?? detail.date,
                capturedAt: Date(),
                source: "mail",
                mailMessageID: detail.id,
                confidence: parsed.confidence,
                needsReview: parsed.needsReview,
                notes: nil)
            Log.app.error("receipt stored: \(merchant) \(amount) card=\(payload.cardLast4 ?? "none") cat=\(payload.category.rawValue)")
            store.append(TrackerEvent(ts: detail.date, kind: .receipt, payload: .receipt(payload)))
        }
        // Mark every fetched id processed (even no-amount: not a purchase).
        let newlyProcessed = details.map(\.id)
        if !newlyProcessed.isEmpty { process(newlyProcessed) }
    }

    private static func merchantGuess(from sender: String) -> String {
        // "Foo Receipts <receipts@foo.com>" → "Foo Receipts"; else domain.
        let v = sender.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespaces) ?? ""
        if !v.isEmpty, !v.contains("@") { return v }
        let domain = sender.replacingOccurrences(of: ".*@", with: "", options: .regularExpression)
            .split(separator: ".").first.map(String.init) ?? "Unknown"
        return domain.capitalized
    }

    // MARK: - AppleScript passes

    private struct Candidate { let id: String }
    private struct Detail {
        let id: String
        let subject: String
        let sender: String
        let body: String
        let date: Date
    }

    private let fld = "`FLD`"
    private let row = "`ROW`"

    /// Pass A: recent message ids + subjects + senders (no body reads).
    private func listCandidates() -> [Candidate]? {
        let script = """
        on esc(s)
            set out to s
            set AppleScript's text item delimiters to linefeed
            set parts to every text item of out
            set AppleScript's text item delimiters to "\\\\n"
            set out to parts as text
            set AppleScript's text item delimiters to (ASCII character 9)
            set parts to every text item of out
            set AppleScript's text item delimiters to "\\\\t"
            set out to parts as text
            set AppleScript's text item delimiters to ""
            return out
        end esc

        tell application "Mail"
            set out to ""
            set cutoff to (current date) - (\(SpendOptions.backfillDays) * days)
            set recent to (every message of inbox whose date received is greater than cutoff)
            set n to count of recent
            if n is greater than \(maxCandidates) then set recent to items 1 thru \(maxCandidates) of recent
            repeat with m in recent
                set mid to (message id of m) as text
                if mid is not "" then
                    set out to out & mid & "\(fld)" & my esc(subject of m) & "\(fld)" & my esc(sender of m) & "\(row)"
                end if
            end repeat
            return out
        end tell
        """
        guard let raw = runScript(script), !raw.isEmpty else { return nil }
        return raw.components(separatedBy: row)
            .filter { !$0.isEmpty }
            .map { $0.components(separatedBy: fld) }
            .filter { $0.count >= 3 && ReceiptParser.looksLikeReceipt(subject: $0[1], sender: $0[2]) }
            .map { Candidate(id: $0[0]) }
    }

    /// Pass B: fetch subject/sender/body/date for the chosen ids only.
    private func fetchDetails(ids: [String]) -> [Detail] {
        guard !ids.isEmpty else { return [] }
        Log.app.error("fetchDetails: fetching \(ids.count) messages")
        let idList = ids.map { $0.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\\", with: "") }
            .map { "\"\($0)\"" }.joined(separator: ", ")
        let script = """
        on esc(s)
            set out to s
            set AppleScript's text item delimiters to linefeed
            set parts to every text item of out
            set AppleScript's text item delimiters to "\\\\n"
            set out to parts as text
            set AppleScript's text item delimiters to (ASCII character 9)
            set parts to every text item of out
            set AppleScript's text item delimiters to "\\\\t"
            set out to parts as text
            set AppleScript's text item delimiters to ""
            return out
        end esc

        tell application "Mail"
            set out to ""
            repeat with midTxt in {\(idList)}
                try
                    set m to (first message of inbox whose message id is midTxt)
                    set epochSec to ((date received of m) - (date "Thursday, January 1, 1970 at 12:00:00 AM")) as text
                    set out to out & (midTxt as text) & "\(fld)" & my esc(subject of m) & "\(fld)" & my esc(sender of m) & "\(fld)" & my esc((content of m) as text) & "\(fld)" & epochSec & "\(row)"
                end try
            end repeat
            return out
        end tell
        """
        guard let raw = runScript(script) else { return [] }
        return raw.components(separatedBy: row)
            .filter { !$0.isEmpty }
            .compactMap { line -> Detail? in
                let parts = line.components(separatedBy: fld)
                guard parts.count >= 5, let epoch = Double(parts[4]) else { return nil }
                return Detail(id: parts[0], subject: Self.unescape(parts[1]),
                              sender: Self.unescape(parts[2]), body: Self.unescape(parts[3]),
                              date: Date(timeIntervalSince1970: epoch))
            }
    }

    private func runScript(_ script: String) -> String? {
        var errorDict: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown"
            Log.app.error("receipt AppleScript error: \(message)")
            return nil
        }
        return result?.stringValue
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\t", with: "\t")
    }

    // MARK: - Dedup state (message ids already processed)

    private var stateFile: URL { store.stateDir.appendingPathComponent("processed-receipt-messages.json") }

    private var processedMessageIDs: Set<String> {
        guard let data = try? Data(contentsOf: stateFile),
              let list = try? SyncFormat.jsonDecoder.decode([String].self, from: data) else { return [] }
        return Set(list)
    }

    private func process(_ ids: [String]) {
        let existing = processedMessageIDs
        let merged = Array(Array(existing.union(ids)).sorted().suffix(2000))   // prune very old ids
        if let data = try? SyncFormat.jsonEncoder.encode(merged) {
            try? data.write(to: stateFile, options: .atomic)
        }
    }
}
