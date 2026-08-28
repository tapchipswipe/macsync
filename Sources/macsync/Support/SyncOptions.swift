import Foundation

/// User-facing toggles persisted in UserDefaults.
enum SyncOptions {
    private static var d: UserDefaults { .standard }

    static var zipArchives: Bool {
        get { d.object(forKey: "macsync.zipArchives") as? Bool ?? true }
        set { d.set(newValue, forKey: "macsync.zipArchives") }
    }

    static var encryptArchives: Bool {
        get { d.bool(forKey: "macsync.encryptArchives") }
        set { d.set(newValue, forKey: "macsync.encryptArchives") }
    }

    static var nightPauseEnabled: Bool {
        get { d.bool(forKey: "macsync.nightPauseEnabled") }
        set { d.set(newValue, forKey: "macsync.nightPauseEnabled") }
    }

    static var nightPauseStartHour: Int {
        get { d.object(forKey: "macsync.nightPauseStart") as? Int ?? 23 }
        set { d.set(newValue, forKey: "macsync.nightPauseStart") }
    }

    static var nightPauseEndHour: Int {
        get { d.object(forKey: "macsync.nightPauseEnd") as? Int ?? 7 }
        set { d.set(newValue, forKey: "macsync.nightPauseEnd") }
    }

    /// True when `date` falls inside the quiet window (handles wrap past midnight).
    static func isInNightPauseWindow(_ date: Date = Date()) -> Bool {
        guard nightPauseEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        let start = nightPauseStartHour, end = nightPauseEndHour
        return start <= end ? (hour >= start && hour < end) : (hour >= start || hour < end)
    }
}
