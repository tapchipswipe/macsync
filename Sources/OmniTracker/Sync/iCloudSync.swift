import Foundation

/// Compiles a day's JSONL buffer into a single structured JSON archive and
/// copies it to iCloud Drive, with local fallbacks.
///
/// Destination order:
///   1. iCloud Drive ubiquity container (FileManager.url(forUbiquityContainerIdentifier:))
///   2. ~/Library/Mobile Documents/com~apple~CloudDocs/OmniTracker/ (works even without ubiquity token)
///   3. ~/Library/Application Support/OmniTracker/Exports/
final class iCloudSync {
    private let store = DataStore.shared
    private let syncQueue = DispatchQueue(label: "com.omnitracker.icloudsync", qos: .utility)
    private let fm = FileManager.default

    /// Syncs every buffered day up to and including `dayString`.
    func syncUnsyncedDays(upToAndIncluding dayString: String) {
        syncQueue.async { [self] in
            for day in store.bufferedDays() where day <= dayString {
                syncDay(day, archiveAfterSuccess: true)
            }
        }
    }

    /// Compiles and exports one day. When `archiveAfterSuccess` is true the
    /// raw buffer file is moved aside so it is not re-exported.
    func syncDay(_ dayString: String, archiveAfterSuccess: Bool) {
        syncQueue.async { [self] in
            let result = performSync(dayString: dayString, archiveAfterSuccess: archiveAfterSuccess)
            store.append(TrackerEvent(ts: Date(), kind: .syncResult, payload: .syncResult(result.payload)))
            store.recordSync(date: Date(), success: result.payload.success, detail: result.detail)
        }
    }

    private struct SyncOutcome {
        let payload: SyncResultPayload
        let detail: String
    }

    private func performSync(dayString: String, archiveAfterSuccess: Bool) -> SyncOutcome {
        let events = store.events(forDay: dayString)
        guard !events.isEmpty else {
            let payload = SyncResultPayload(
                date: dayString, destination: "None", filePath: nil,
                eventCount: 0, success: false, errorMessage: "No events buffered"
            )
            return SyncOutcome(payload: payload, detail: "\(dayString): no events")
        }

        let archive = DayArchive(
            date: dayString,
            generatedAt: Date(),
            generator: "OmniTracker 0.1.0",
            eventCount: events.count,
            eventsByKind: Dictionary(grouping: events, by: { $0.kind.rawValue }).mapValues(\.count),
            summary: Self.buildSummary(events: events),
            events: events
        )

        guard let jsonData = try? OmniFormat.prettyJSONEncoder.encode(archive) else {
            let payload = SyncResultPayload(
                date: dayString, destination: "None", filePath: nil,
                eventCount: events.count, success: false, errorMessage: "JSON encoding failed"
            )
            return SyncOutcome(payload: payload, detail: "\(dayString): encoding failed")
        }

        let filename = "OmniTracker_\(dayString).json"

        if let destination = resolveDestination() {
            do {
                try fm.createDirectory(at: destination.dir, withIntermediateDirectories: true)
                let fileURL = destination.dir.appendingPathComponent(filename)
                try jsonData.write(to: fileURL, options: .atomic)
                if archiveAfterSuccess {
                    store.archiveAndClear(dayString: dayString)
                }
                let payload = SyncResultPayload(
                    date: dayString, destination: destination.name, filePath: fileURL.path,
                    eventCount: events.count, success: true, errorMessage: nil
                )
                return SyncOutcome(payload: payload, detail: "\(dayString): \(events.count) events → \(destination.name)")
            } catch {
                let payload = SyncResultPayload(
                    date: dayString, destination: destination.name, filePath: nil,
                    eventCount: events.count, success: false, errorMessage: error.localizedDescription
                )
                return SyncOutcome(payload: payload, detail: "\(dayString): write failed - \(error.localizedDescription)")
            }
        }

        let payload = SyncResultPayload(
            date: dayString, destination: "None", filePath: nil,
            eventCount: events.count, success: false, errorMessage: "No writable destination"
        )
        return SyncOutcome(payload: payload, detail: "\(dayString): no destination")
    }


    // MARK: - Destination resolution

    private struct Destination {
        let name: String
        let dir: URL
    }

    private func resolveDestination() -> Destination? {
        // 1. True ubiquity container (requires iCloud entitlement + account).
        if let ubiquity = fm.url(forUbiquityContainerIdentifier: nil) {
            return Destination(
                name: "iCloud",
                dir: ubiquity.appendingPathComponent("Documents/OmniTracker", isDirectory: true)
            )
        }
        // 2. iCloud Drive root via well-known path (no entitlement needed).
        let cloudDocs = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: cloudDocs.path, isDirectory: &isDir), isDir.boolValue {
            return Destination(
                name: "iCloudDrive",
                dir: cloudDocs.appendingPathComponent("OmniTracker", isDirectory: true)
            )
        }
        // 3. Local exports folder (never fails).
        return Destination(name: "LocalExports", dir: store.exportsDir)
    }

    // MARK: - Summary

    static func buildSummary(events: [TrackerEvent]) -> DaySummary {
        var keystrokes = 0
        var clicks = 0
        var cursor: Double = 0
        var idle: TimeInterval = 0
        var appUsage: [String: TimeInterval] = [:]
        var batteryMin: Int?
        var batteryMax: Int?

        for event in events {
            switch event.payload {
            case .inputMetrics(let p):
                keystrokes += p.keystrokeCount
                clicks += p.mouseClickCount
                cursor += p.cursorDistancePoints
            case .idleSession(let p):
                idle += p.durationSeconds
            case .appFocus(let p):
                appUsage[p.appName, default: 0] += p.durationSeconds
            case .hardwareStatus(let p):
                if let pct = p.batteryPercent {
                    batteryMin = min(batteryMin ?? pct, pct)
                    batteryMax = max(batteryMax ?? pct, pct)
                }
            default:
                break
            }
        }
        return DaySummary(
            totalKeystrokes: keystrokes,
            totalClicks: clicks,
            totalCursorDistancePoints: cursor,
            appUsageSeconds: appUsage,
            idleSeconds: idle,
            batteryMin: batteryMin,
            batteryMax: batteryMax
        )
    }
}
