import Foundation

/// Append-only JSONL buffer rooted at
/// ~/Library/Application Support/OmniTracker/
///
/// Layout:
///   buffer/events-YYYY-MM-DD.jsonl   one TrackerEvent per line (crash-safe append)
///   state/input-metrics.json         latest un-flushed input counters
///   state/daily-stats.json           per-day event counts + last sync info
///   Exports/                         local fallback sync destination
final class DataStore {
    static let shared = DataStore()

    let root: URL
    let bufferDir: URL
    let stateDir: URL
    let exportsDir: URL

    private let writeQueue = DispatchQueue(label: "com.omnitracker.datastore", qos: .utility)
    private let lock = NSLock()

    /// Counters read on main, written under lock.
    private(set) var todayEventCount: Int = 0
    private(set) var lastSyncDate: Date?
    private(set) var lastSyncSuccess: Bool = false
    private(set) var lastSyncDetail: String = "Never synced"

    var onStatsChanged: (() -> Void)?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        root = appSupport.appendingPathComponent("OmniTracker", isDirectory: true)
        bufferDir = root.appendingPathComponent("buffer", isDirectory: true)
        stateDir = root.appendingPathComponent("state", isDirectory: true)
        exportsDir = root.appendingPathComponent("Exports", isDirectory: true)
        for dir in [root, bufferDir, stateDir, exportsDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        loadState()
    }

    // MARK: - File paths

    func bufferFile(for dayString: String) -> URL {
        bufferDir.appendingPathComponent("events-\(dayString).jsonl")
    }

    private var stateFile: URL { stateDir.appendingPathComponent("daily-stats.json") }
    private var inputStateFile: URL { stateDir.appendingPathComponent("input-metrics.json") }

    // MARK: - Event append

    func append(_ event: TrackerEvent) {
        writeQueue.async { [self] in
            let day = OmniFormat.dayString(for: event.ts)
            let file = bufferFile(for: day)
            guard let data = try? OmniFormat.jsonEncoder.encode(event) else { return }
            var line = data
            line.append(0x0A) // newline
            if FileManager.default.fileExists(atPath: file.path) {
                if let handle = try? FileHandle(forWritingTo: file) {
                    defer { try? handle.close() }
                    do {
                        try handle.seekToEnd()
                        try handle.write(contentsOf: line)
                    } catch {
                        NSLog("OmniTracker DataStore append error: \(error)")
                    }
                }
            } else {
                try? line.write(to: file, options: .atomic)
            }
            lock.lock()
            if day == OmniFormat.dayString() { todayEventCount += 1 }
            lock.unlock()
            DispatchQueue.main.async { [weak self] in self?.onStatsChanged?() }
        }
    }

    // MARK: - Day read

    func events(forDay dayString: String) -> [TrackerEvent] {
        let file = bufferFile(for: dayString)
        guard let data = try? Data(contentsOf: file) else { return [] }
        var events: [TrackerEvent] = []
        data.split(separator: 0x0A).forEach { slice in
            if let ev = try? OmniFormat.jsonDecoder.decode(TrackerEvent.self, from: Data(slice)) {
                events.append(ev)
            }
        }
        return events
    }

    func bufferedDays() -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: bufferDir.path) else { return [] }
        return files.compactMap { name -> String? in
            guard name.hasPrefix("events-"), name.hasSuffix(".jsonl") else { return nil }
            return String(name.dropFirst(7).dropLast(6))
        }.sorted()
    }


    func archiveAndClear(dayString: String) {
        let file = bufferFile(for: dayString)
        let archiveDir = root.appendingPathComponent("archive", isDirectory: true)
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        let dest = archiveDir.appendingPathComponent("events-\(dayString).jsonl")
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.moveItem(at: file, to: dest)
    }

    // MARK: - Stats persistence

    private struct PersistedState: Codable {
        var eventCounts: [String: Int]
        var lastSyncDate: Date?
        var lastSyncSuccess: Bool
        var lastSyncDetail: String
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: stateFile),
              let state = try? OmniFormat.jsonDecoder.decode(PersistedState.self, from: data) else { return }
        todayEventCount = state.eventCounts[OmniFormat.dayString()] ?? 0
        lastSyncDate = state.lastSyncDate
        lastSyncSuccess = state.lastSyncSuccess
        lastSyncDetail = state.lastSyncDetail
    }

    func recordSync(date: Date, success: Bool, detail: String) {
        lock.lock()
        lastSyncDate = date
        lastSyncSuccess = success
        lastSyncDetail = detail
        lock.unlock()
        persistState()
        DispatchQueue.main.async { [weak self] in self?.onStatsChanged?() }
    }

    private func persistState() {
        writeQueue.async { [self] in
            lock.lock()
            let state = PersistedState(
                eventCounts: [OmniFormat.dayString(): todayEventCount],
                lastSyncDate: lastSyncDate,
                lastSyncSuccess: lastSyncSuccess,
                lastSyncDetail: lastSyncDetail
            )
            lock.unlock()
            if let data = try? OmniFormat.prettyJSONEncoder.encode(state) {
                try? data.write(to: stateFile, options: .atomic)
            }
        }
    }

    // MARK: - Input metrics snapshot (survives restart)

    struct InputSnapshot: Codable {
        var bucketStart: Date
        var keystrokes: Int
        var clicks: Int
        var scrolls: Int
        var cursorDistance: Double
        var activeSeconds: Int
    }

    func saveInputSnapshot(_ snapshot: InputSnapshot) {
        writeQueue.async { [self] in
            if let data = try? OmniFormat.jsonEncoder.encode(snapshot) {
                try? data.write(to: inputStateFile, options: .atomic)
            }
        }
    }

    func loadInputSnapshot() -> InputSnapshot? {
        guard let data = try? Data(contentsOf: inputStateFile) else { return nil }
        return try? OmniFormat.jsonDecoder.decode(InputSnapshot.self, from: data)
    }
}
