import CryptoKit
import Foundation

enum AggregatorTests {
    static func run() {
        var events: [TrackerEvent] = []
        let now = Date()
        events.append(TrackerEvent(ts: now, kind: .inputMetrics, payload: .inputMetrics(
            InputMetricsPayload(bucketStart: now, bucketEnd: now, keystrokeCount: 42,
                                mouseClickCount: 3, scrollEvents: 1, cursorDistancePoints: 100,
                                activeSeconds: 60, tapEnabled: true))))
        events.append(TrackerEvent(ts: now, kind: .appFocus, payload: .appFocus(
            AppFocusPayload(appName: "Xcode", bundleID: nil, pid: 1,
                            start: now, end: now.addingTimeInterval(120), durationSeconds: 120))))
        events.append(TrackerEvent(ts: now, kind: .idleSession, payload: .idleSession(
            IdleSessionPayload(start: now, end: now.addingTimeInterval(300), durationSeconds: 300))))

        let s = TodayAggregator.compute(events: events, archived: [])
        expect(s.keystrokes == 42, "keystrokes sum")
        expect(s.clicks == 3, "clicks sum")
        expect(s.cursorDistance == 100, "cursor sum")
        expect(s.focusSessions == 1, "focus sessions")
        expect(s.apps.first?.name == "Xcode", "top app")
        expect(s.categories.first?.category == .code, "Xcode tagged as Code (#3)")
        expect(s.idleSeconds == 300, "idle seconds")
        expect(!s.insights.isEmpty, "plain-English insights (#18)")

        // Anomaly (#4): big Xcode day vs small archived days
        var archived: [(day: String, events: [TrackerEvent])] = []
        for i in 1...3 {
            archived.append(("2026-0\(i)-0\(i)", [TrackerEvent(ts: now, kind: .appFocus, payload: .appFocus(
                AppFocusPayload(appName: "Xcode", bundleID: nil, pid: 1, start: now,
                                end: now.addingTimeInterval(60), durationSeconds: 1800)))]))
        }
        let big = TodayAggregator.compute(events: [TrackerEvent(ts: now, kind: .appFocus, payload: .appFocus(
            AppFocusPayload(appName: "Xcode", bundleID: nil, pid: 1, start: now,
                            end: now.addingTimeInterval(7200), durationSeconds: 7200)))], archived: archived)
        expect(big.anomaly != nil, "anomaly fires (#4)")
    }
}

enum CryptoTests {
    static func run() {
        let key = SymmetricKey(size: .bits256)
        let secret = Data("macsync archive test payload 🔒".utf8)
        do {
            let sealed = try CryptoVault.seal(secret, key: key)
            expect(sealed != secret, "ciphertext differs")
            let opened = try CryptoVault.open(sealed, key: key)
            expect(opened == secret, "AES-GCM roundtrip (#9)")
        } catch { expect(false, "crypto threw: \(error)") }
    }
}

enum CategoryTests {
    static func run() {
        expect(ActivityCategory.forApp("Xcode") == .code, "Xcode → Code")
        expect(ActivityCategory.forApp("Slack") == .comms, "Slack → Comms")
        expect(ActivityCategory.forApp("Figma") == .design, "Figma → Design")
        expect(ActivityCategory.forURL("https://github.com/tapchipswipe/macsync") == .code, "github → Code (#3)")
        expect(ActivityCategory.forURL("https://youtube.com/watch") == .media, "youtube → Media")
    }
}
