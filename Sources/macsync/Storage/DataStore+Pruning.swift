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
}
