import Foundation

/// Daily sync scheduler.
///
/// Primary mechanism: a repeating wall-clock Timer that computes the next
/// occurrence of the configured sync time (default 23:59 local) and fires
/// once per day. NSBackgroundActivityScheduler is installed as a watchdog:
/// if the daily timer missed (e.g., Mac was asleep at 23:59), the background
/// activity (tolerance-checked, min interval 1 h) performs the catch-up sync
/// for any buffered days that have not yet been exported.
final class SyncScheduler {
    static let defaultSyncHour = 23
    static let defaultSyncMinute = 59

    private let syncEngine: iCloudSync
    private var dailyTimer: Timer?
    private var backgroundActivity: NSBackgroundActivityScheduler?
    private var lastSyncDay: String?

    var onSyncFired: (() -> Void)?

    /// Next scheduled wall-clock sync, for display in the menu.
    private(set) var nextScheduledSync: Date?

    init(syncEngine: iCloudSync) {
        self.syncEngine = syncEngine
    }

    func start() {
        scheduleDailyTimer()
        installBackgroundActivity()
    }

    func stop() {
        dailyTimer?.invalidate()
        dailyTimer = nil
        if let activity = backgroundActivity {
            activity.invalidate()
            backgroundActivity = nil
        }
    }

    // MARK: - Daily wall-clock timer

    private func scheduleDailyTimer() {
        dailyTimer?.invalidate()
        let next = Self.nextSyncDate(from: Date())
        nextScheduledSync = next
        let interval = next.timeIntervalSinceNow
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            self?.fireDailySync()
        }
        RunLoop.main.add(timer, forMode: .common)
        dailyTimer = timer
        NSLog("OmniTracker: next daily sync scheduled for \(next) (in \(Int(interval))s)")
    }

    static func nextSyncDate(from now: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = defaultSyncHour
        components.minute = defaultSyncMinute
        components.second = 0
        let today = Calendar.current.date(from: components)!
        if today > now { return today }
        return Calendar.current.date(byAdding: .day, value: 1, to: today)!
    }

    private func fireDailySync() {
        let today = OmniFormat.dayString()
        // Sync *yesterday* (complete day) plus any earlier unsynced days.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        syncEngine.syncUnsyncedDays(upToAndIncluding: OmniFormat.dayString(for: yesterday))
        lastSyncDay = today
        onSyncFired?()
        scheduleDailyTimer()
    }

    // MARK: - Background watchdog (catches sleep/missed runs)

    private func installBackgroundActivity() {
        let activity = NSBackgroundActivityScheduler(identifier: "com.omnitracker.sync")
        activity.repeats = true
        activity.interval = 3600          // check hourly
        activity.tolerance = 1800
        activity.qualityOfService = .utility
        activity.schedule { [weak self] completion in
            guard let self else {
                completion(.finished)
                return
            }
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let yesterdayStr = OmniFormat.dayString(for: yesterday)
            let unsynced = DataStore.shared.bufferedDays().filter { $0 <= yesterdayStr }
            if !unsynced.isEmpty {
                NSLog("OmniTracker: watchdog syncing \(unsynced.count) missed day(s): \(unsynced)")
                self.syncEngine.syncUnsyncedDays(upToAndIncluding: yesterdayStr)
                self.onSyncFired?()
            }
            completion(.finished)
        }
        backgroundActivity = activity
    }

    // MARK: - Manual sync (from menu)

    /// Compiles and uploads *today's* logs so far (non-destructive — buffer stays).
    func syncNow() {
        syncEngine.syncDay(OmniFormat.dayString(), archiveAfterSuccess: false)
        onSyncFired?()
    }
}
