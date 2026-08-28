import Foundation

// MARK: - Dashboard / menu aggregate models & computation

struct AppUsage: Identifiable {
    let id = UUID()
    let name: String
    let seconds: TimeInterval
}

struct ActivityPoint: Identifiable {
    let id = UUID()
    let minute: Int          // minutes since local midnight
    let keystrokes: Int
    let activeSeconds: Int
}

struct BatterySample: Identifiable {
    let id = UUID()
    let time: Date
    let level: Double?       // nil when no battery (desktop)
}

struct PageVisit: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
}

struct TodayStats {
    var eventCount = 0
    var keystrokes = 0
    var clicks = 0
    var scrolls = 0
    var cursorDistance = 0.0
    var activeSeconds = 0.0
    var idleSeconds = 0.0
    var batteryPercent: Int?
    var batteryCharging: Bool?
    var cpuLoad = 0.0
    var memoryPressure = 0.0
    var focusSessions = 0
    var apps: [AppUsage] = []
    var activity: [ActivityPoint] = []
    var batteryTrace: [BatterySample] = []
    var pages: [PageVisit] = []

    var activeMinutes: Double { activeSeconds / 60.0 }
    var activeHours: Double { activeSeconds / 3600.0 }

    static let empty = TodayStats()
}

enum TodayAggregator {
    /// Recompute today's dashboard stats from the day's persisted events.
    /// Aggregates in-memory every refresh; cheap enough for a 30s poll.
    static func compute(events: [TrackerEvent]) -> TodayStats {
        var s = TodayStats()
        s.eventCount = events.count

        var appSeconds: [String: TimeInterval] = [:]
        var minutes: [Int: (keystrokes: Int, active: Int)] = [:]
        var batterySteps: [BatterySample] = []
        var pageCounts: [String: Int] = [:]
        let cal = Calendar.current

        for e in events {
            switch e.payload {
            case .inputMetrics(let p):
                s.keystrokes += p.keystrokeCount
                s.clicks += p.mouseClickCount
                s.scrolls += p.scrollEvents
                s.cursorDistance += p.cursorDistancePoints
                s.activeSeconds += Double(p.activeSeconds)
                // Map into per-minute bucket using bucketStart.
                let comps = cal.dateComponents([.hour, .minute], from: p.bucketStart)
                let minute = comps.hour! * 60 + comps.minute!
                var b = minutes[minute] ?? (0, 0)
                b.keystrokes += p.keystrokeCount
                b.active += p.activeSeconds
                minutes[minute] = b
            case .idleSession(let p):
                s.idleSeconds += p.durationSeconds
            case .appFocus(let p):
                s.focusSessions += 1
                appSeconds[p.appName, default: 0] += p.durationSeconds
            case .hardwareStatus(let p):
                s.cpuLoad = p.cpuLoadPercent
                s.memoryPressure = p.memoryPressurePercent
                if let pct = p.batteryPercent {
                    s.batteryPercent = pct
                    s.batteryCharging = p.batteryCharging
                    batterySteps.append(BatterySample(time: p.observedAt, level: Double(pct)))
                }
            case .browserActivity(let p):
                if p.success, let title = p.tabTitle, !title.isEmpty {
                    pageCounts[title, default: 0] += 1
                }
            default:
                break
            }
        }

        // Apps sorted by usage.
        s.apps = appSeconds
            .map { AppUsage(name: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }

        // Activity timeline sorted by minute.
        s.activity = minutes
            .map { ActivityPoint(minute: $0.key, keystrokes: $0.value.keystrokes, activeSeconds: $0.value.active) }
            .sorted { $0.minute < $1.minute }

        s.batteryTrace = batterySteps

        s.pages = pageCounts
            .map { PageVisit(title: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(6)
            .map { $0 }

        return s
    }
}