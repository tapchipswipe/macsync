import Foundation

/// Unified event envelope written to the JSONL buffer.
/// Every collector emits these; the sync step groups them by `kind`.
struct TrackerEvent: Codable {
    let ts: Date
    let kind: EventKind
    let payload: Payload

    enum EventKind: String, Codable {
        case appFocus
        case windowFocus
        case inputMetrics
        case browserActivity
        case hardwareStatus
        case idleSession
        case locationPing
        case syncResult
    }

    enum Payload: Codable {
        case appFocus(AppFocusPayload)
        case windowFocus(WindowFocusPayload)
        case inputMetrics(InputMetricsPayload)
        case browserActivity(BrowserActivityPayload)
        case hardwareStatus(HardwareStatusPayload)
        case idleSession(IdleSessionPayload)
        case locationPing(LocationPingPayload)
        case syncResult(SyncResultPayload)

        private enum CodingKeys: String, CodingKey {
            case type
            case appFocus, windowFocus, inputMetrics, browserActivity
            case hardwareStatus, idleSession, locationPing, syncResult
        }

        private enum PayloadType: String, Codable {
            case appFocus, windowFocus, inputMetrics, browserActivity
            case hardwareStatus, idleSession, locationPing, syncResult
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(PayloadType.self, forKey: .type)
            switch type {
            case .appFocus:        self = .appFocus(try c.decode(AppFocusPayload.self, forKey: .appFocus))
            case .windowFocus:     self = .windowFocus(try c.decode(WindowFocusPayload.self, forKey: .windowFocus))
            case .inputMetrics:    self = .inputMetrics(try c.decode(InputMetricsPayload.self, forKey: .inputMetrics))
            case .browserActivity: self = .browserActivity(try c.decode(BrowserActivityPayload.self, forKey: .browserActivity))
            case .hardwareStatus:  self = .hardwareStatus(try c.decode(HardwareStatusPayload.self, forKey: .hardwareStatus))
            case .idleSession:     self = .idleSession(try c.decode(IdleSessionPayload.self, forKey: .idleSession))
            case .locationPing:    self = .locationPing(try c.decode(LocationPingPayload.self, forKey: .locationPing))
            case .syncResult:      self = .syncResult(try c.decode(SyncResultPayload.self, forKey: .syncResult))
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .appFocus(let p):        try c.encode(PayloadType.appFocus, forKey: .type);        try c.encode(p, forKey: .appFocus)
            case .windowFocus(let p):     try c.encode(PayloadType.windowFocus, forKey: .type);     try c.encode(p, forKey: .windowFocus)
            case .inputMetrics(let p):    try c.encode(PayloadType.inputMetrics, forKey: .type);    try c.encode(p, forKey: .inputMetrics)
            case .browserActivity(let p): try c.encode(PayloadType.browserActivity, forKey: .type); try c.encode(p, forKey: .browserActivity)
            case .hardwareStatus(let p):  try c.encode(PayloadType.hardwareStatus, forKey: .type);  try c.encode(p, forKey: .hardwareStatus)
            case .idleSession(let p):     try c.encode(PayloadType.idleSession, forKey: .type);     try c.encode(p, forKey: .idleSession)
            case .locationPing(let p):    try c.encode(PayloadType.locationPing, forKey: .type);    try c.encode(p, forKey: .locationPing)
            case .syncResult(let p):      try c.encode(PayloadType.syncResult, forKey: .type);      try c.encode(p, forKey: .syncResult)
            }
        }
    }
}


// MARK: - Payloads

struct AppFocusPayload: Codable {
    let appName: String
    let bundleID: String?
    let pid: Int32
    let start: Date
    let end: Date
    let durationSeconds: TimeInterval
}

struct WindowFocusPayload: Codable {
    let appName: String
    let windowTitle: String?   // nil when Screen Recording permission is missing
    let start: Date
    let end: Date
    let durationSeconds: TimeInterval
}

/// Aggregated input METADATA ONLY. No keycodes, no characters, ever.
struct InputMetricsPayload: Codable {
    let bucketStart: Date
    let bucketEnd: Date
    let keystrokeCount: Int
    let mouseClickCount: Int
    let scrollEvents: Int
    let cursorDistancePoints: Double
    let activeSeconds: Int      // seconds within the bucket with any input
    let tapEnabled: Bool        // false if Accessibility permission was missing
}

struct BrowserActivityPayload: Codable {
    let browser: String         // "Safari" | "Chrome"
    let url: String?
    let tabTitle: String?
    let observedAt: Date
    let success: Bool
    let errorMessage: String?
}

struct HardwareStatusPayload: Codable {
    let observedAt: Date
    let batteryPercent: Int?    // nil on desktop Macs
    let batteryCharging: Bool?
    let onBattery: Bool?
    let timeRemainingMinutes: Int?
    let cpuLoadPercent: Double
    let memoryUsedBytes: UInt64
    let memoryTotalBytes: UInt64
    let memoryPressurePercent: Double
    let networkBytesInPerSec: UInt64
    let networkBytesOutPerSec: UInt64
    let primaryInterface: String?
}

struct IdleSessionPayload: Codable {
    let start: Date
    let end: Date
    let durationSeconds: TimeInterval
}

struct LocationPingPayload: Codable {
    let observedAt: Date
    let latitude: Double?
    let longitude: Double?
    let accuracyMeters: Double?
    let denied: Bool
    let errorMessage: String?
}

struct SyncResultPayload: Codable {
    let date: String            // yyyy-MM-dd of the synced day
    let destination: String     // "iCloud" | "LocalFallback" | "LocalExports"
    let filePath: String?
    let eventCount: Int
    let success: Bool
    let errorMessage: String?
}

// MARK: - Day archive (compiled output)

struct DayArchive: Codable {
    let date: String
    let generatedAt: Date
    let generator: String
    let eventCount: Int
    let eventsByKind: [String: Int]
    let summary: DaySummary
    let events: [TrackerEvent]
}

struct DaySummary: Codable {
    let totalKeystrokes: Int
    let totalClicks: Int
    let totalCursorDistancePoints: Double
    let appUsageSeconds: [String: TimeInterval]   // appName -> seconds
    let idleSeconds: TimeInterval
    let batteryMin: Int?
    let batteryMax: Int?
}

// MARK: - Shared formatting

enum OmniFormat {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let prettyJSONEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func dayString(for date: Date = Date()) -> String {
        dayFormatter.string(from: date)
    }
}
