import Foundation

/// Tax-friendly export of tracked receipts to ~/Documents/macsync-spend/.
/// CSV columns are chosen for direct import into spreadsheets / tax software.
enum SpendExport {

    static var exportDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("macsync-spend", isDirectory: true)
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f
    }()

    // MARK: - Pure CSV builder (unit-tested)

    static func csvString(receipts: [ReceiptPayload]) -> String {
        var lines = ["Date,Merchant,Category,Amount,Currency,CardLast4,Deductible,Source,Notes"]
        for r in receipts.sorted(by: { $0.transactionDate < $1.transactionDate }) {
            let date = dateFmt.string(from: r.transactionDate)
            let deductible = r.category.businessDeductible ? "yes" : "no"
            let card = r.cardLast4 ?? (r.source == "manual" ? "" : "Unknown")
            let row = [date, r.merchant, r.category.rawValue,
                       NSDecimalNumber(decimal: r.amount).stringValue, r.currency,
                       card, deductible, r.source, r.notes ?? ""]
                .map(escape)
                .joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    // MARK: - File export

    @discardableResult
    static func exportCSV(receipts: [ReceiptPayload]) -> URL? {
        let text = csvString(receipts: receipts)
        return write(text, filename: "macsync-receipts-\(dateFmt.string(from: Date())).csv")
    }

    @discardableResult
    static func exportJSON(receipts: [ReceiptPayload]) -> URL? {
        guard let data = try? SyncFormat.prettyJSONEncoder.encode(receipts) else { return nil }
        return write(Data(data), filename: "macsync-receipts-\(dateFmt.string(from: Date())).json")
    }

    private static func write(_ text: String, filename: String) -> URL? {
        write(Data(text.utf8), filename: filename)
    }

    private static func write(_ data: Data, filename: String) -> URL? {
        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            let url = exportDir.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            Log.app.error("spend export failed: \(error.localizedDescription)")
            return nil
        }
    }
}