import Foundation

struct AppUsage: Identifiable {
    let id = UUID()
    let name: String
    let seconds: TimeInterval
}

struct ActivityPoint: Identifiable {
    let id = UUID()
    let minute: Int
    let keystrokes: Int
    let activeSeconds: Int
}

struct BatterySample: Identifiable {
    let id = UUID()
    let time: Date
    let level: Double?
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
    var categories: [CategoryUsage] = []
    var zombieSeconds = 0.0
    var insights: [String] = []
    var anomaly: String?

    var activeMinutes: Double { activeSeconds / 60.0 }
    var activeHours: Double { activeSeconds / 3600.0 }
    var topInsight: String? { anomaly ?? insights.first }

    static let empty = TodayStats()
}

enum TodayAggregator {
    static func compute(events: [TrackerEvent], archived: [(day: String, events: [TrackerEvent])] = []) -> TodayStats {
        var s = TodayStats()
        s.eventCount = events.count

        var appSeconds: [String: TimeInterval] = [:]
        var minutes: [Int: (keystrokes: Int, active: Int)] = [:]
        var inputMinutes = Set<Int>()
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
                let comps = cal.dateComponents([.hour, .minute], from: p.bucketStart)
                let minute = comps.hour! * 60 + comps.minute!
                var b = minutes[minute] ?? (0, 0)
                b.keystrokes += p.keystrokeCount
                b.active += p.activeSeconds
                minutes[minute] = b
                if p.keystrokeCount > 0 || p.mouseClickCount > 0 { inputMinutes.insert(minute) }
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

        // Zombie-scroll (#5): focus-covered minutes with zero input.
        var focusMinutes = Set<Int>()
        for e in events {
            if case .appFocus(let p) = e.payload {
                let startH = cal.component(.hour, from: p.start), startM = cal.component(.minute, from: p.start)
                let start = startH * 60 + startM
                let dur = min(p.durationSeconds, 8 * 3600)
                let span = Int(dur / 60)
                for off in 0...max(span, 0) { focusMinutes.insert((start + off) % 1440) }
            }
        }
        s.zombieSeconds = Double(focusMinutes.subtracting(inputMinutes).count) * 60.0

        // Apps + categories (#3)
        s.apps = appSeconds
            .map { AppUsage(name: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
        var catSeconds: [ActivityCategory: TimeInterval] = [:]
        for a in s.apps { catSeconds[ActivityCategory.forApp(a.name), default: 0] += a.seconds }
        s.categories = catSeconds.map { CategoryUsage(category: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }

        s.activity = minutes
            .map { ActivityPoint(minute: $0.key, keystrokes: $0.value.keystrokes, activeSeconds: $0.value.active) }
            .sorted { $0.minute < $1.minute }
        s.batteryTrace = batterySteps
        s.pages = pageCounts.map { PageVisit(title: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }.prefix(6).map { $0 }

        s.insights = InsightsBuilder.summary(s)
        s.anomaly = InsightsBuilder.anomaly(s, archived: archived)
        return s
    }
}
