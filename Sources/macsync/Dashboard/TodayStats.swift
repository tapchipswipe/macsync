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
    // v0.4.0 context pack
    var meetingSeconds = 0.0                // camera/mic-in-use ∩ meeting heuristics
    var mediaSeconds: [String: TimeInterval] = [:]  // playback minutes by app
    var clipboardCopies = 0
    var mailUnread: Int?
    var mailReceivedToday: Int?
    var mailSentToday: Int?
    var mailTopSenders: [String]?
    var screenLockCount = 0
    var wakeCount = 0
    var appLaunches: [String: Int] = [:]    // app launch frequency
    var wifiSSID: String?
    var onVPN: Bool?
    var focusActive: Bool?
    var nowPlaying: NowPlayingPayload?      // latest track observed

    var activeMinutes: Double { activeSeconds / 60.0 }
    var activeHours: Double { activeSeconds / 3600.0 }
    var meetingMinutes: Double { meetingSeconds / 60.0 }
    var topInsight: String? { anomaly ?? insights.first }
    var topMediaApp: String? { mediaSeconds.max { $0.value < $1.value }?.key }

    /// Focus score (#1): 0–100 blend of active time vs. an 8h goal (50%),
    /// deep-work streaks — focus sessions ≥ 25 min (30%), and low zombie-scroll
    /// share — minutes with a focused window but zero input (20%).
    var focusScore: Int {
        let activeScore = min(1.0, activeMinutes / 480.0) * 50.0
        let deepStreaks = apps.filter { $0.seconds >= 25 * 60 }.count
        let streakScore = min(1.0, Double(deepStreaks) / 3.0) * 30.0
        let totalFocusSec = max(activeSeconds + idleSeconds, 1)
        let zombieShare = zombieSeconds / totalFocusSec
        let zombieScore = max(0.0, 1.0 - zombieShare) * 20.0
        return Int(min(100, activeScore + streakScore + zombieScore).rounded())
    }

    var focusScoreLabel: String {
        switch focusScore {
        case 80...: return "Deep focus"
        case 60..<80: return "Strong"
        case 40..<60: return "Steady"
        case 20..<40: return "Scattered"
        default: return "Warming up"
        }
    }

    /// Compact "2h 14m" / "34m" readout for the menu-bar title mode (#7).
    var activeMenuText: String {
        let m = Int(activeMinutes)
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(m)m"
    }

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
        var cameraStates: [(time: Date, cam: Bool)] = []
        var micStates: [(time: Date, mic: Bool)] = []
        var playStates: [(time: Date, app: String?, playing: Bool)] = []
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
            // ── v0.4.0 context pack ──
            case .sessionEvent(let p):
                switch p.event {
                case .screenLocked: s.screenLockCount += 1
                case .systemWake: s.wakeCount += 1
                default: break
                }
            case .cameraMicState(let p):
                cameraStates.append((p.observedAt, p.cameraActive))
                micStates.append((p.observedAt, p.microphoneActive))
            case .nowPlaying(let p):
                s.nowPlaying = p
                playStates.append((p.observedAt, p.appName, p.isPlaying))
            case .networkContext(let p):
                s.wifiSSID = p.ssid
                s.onVPN = p.onVPN
            case .clipboardMetric(let p):
                s.clipboardCopies += p.copiesInInterval
            case .focusModeState(let p):
                s.focusActive = p.focusActive
            case .appLifecycle(let p):
                if p.event == .launched { s.appLaunches[p.appName, default: 0] += 1 }
            case .mailStats(let p):
                if p.success {
                    s.mailUnread = p.unreadCount
                    s.mailReceivedToday = p.receivedToday
                    s.mailSentToday = p.sentToday
                    if let senders = p.topSenders { s.mailTopSenders = senders }
                }
            default:
                break
            }
        }

        // ── Meeting inference ──
        // Each cameraMic sample carries (cam, mic, frontmostApp) at ~30s cadence.
        // A sample counts as "meeting" when the camera is on, or the mic is on
        // while a known meeting/call app was frontmost. Consecutive meeting
        // samples are latched into intervals (gap tolerance = 2.5x poll interval).
        let meetingApps: Set<String> = ["zoom", "teams", "meet", "slack", "facetime", "webex", "discord", "huddle"]
        var isMeetingSample = [(time: Date, meeting: Bool)]()
        for e in events {
            if case .cameraMicState(let p) = e.payload {
                var meeting = p.cameraActive
                if p.microphoneActive, let app = p.frontmostApp {
                    meeting = meeting || meetingApps.contains { app.lowercased().contains($0) }
                }
                isMeetingSample.append((p.observedAt, meeting))
            }
        }
        if !isMeetingSample.isEmpty {
            var meetingStart = Date?.none
            var prev: Date = isMeetingSample[0].time
            let maxGap: TimeInterval = 75   // bridge short poll hiccups
            for smp in isMeetingSample {
                if smp.meeting {
                    if meetingStart == nil { meetingStart = smp.time }
                } else {
                    if meetingStart != nil, smp.time.timeIntervalSince(prev) <= maxGap {
                        // still same interval; contiguous non-meeting gap too short
                    } else if let ms = meetingStart {
                        s.meetingSeconds += smp.time.timeIntervalSince(ms)
                        meetingStart = nil
                    }
                }
                prev = smp.time
            }
            if let ms = meetingStart, let last = isMeetingSample.last {
                s.meetingSeconds += last.time.timeIntervalSince(ms)
            }
        }

        // ── Media playback seconds by app ──
        // NowPlaying events fire on track change/stop; each playing sample owns
        // the interval to the next sample.
        for (i, st) in playStates.enumerated() {
            guard st.playing, let app = st.app, !app.isEmpty else { continue }
            let end = i + 1 < playStates.count ? playStates[i + 1].time : st.time.addingTimeInterval(60)
            s.mediaSeconds[app, default: 0] += max(0, end.timeIntervalSince(st.time))
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
