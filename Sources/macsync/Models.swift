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
        // v0.4.0 context pack
        case sessionEvent
        case cameraMicState
        case nowPlaying
        case networkContext
        case clipboardMetric
        case focusModeState
        case appLifecycle
        case mailStats
        // v0.5.0 receipts & spending
        case receipt
        // v0.6.0 deep telemetry suite
        case gitVelocity
        case cliCommand
        case thermalState
        case audioRoute
        case displayTopology
        case bluetoothBattery
        case networkQuality
        case notificationEvent
        case diskHygiene
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
        case sessionEvent(SessionEventPayload)
        case cameraMicState(CameraMicPayload)
        case nowPlaying(NowPlayingPayload)
        case networkContext(NetworkContextPayload)
        case clipboardMetric(ClipboardMetricPayload)
        case focusModeState(FocusModePayload)
        case appLifecycle(AppLifecyclePayload)
        case mailStats(MailStatsPayload)
        case receipt(ReceiptPayload)
        case gitVelocity(GitVelocityPayload)
        case cliCommand(CLICommandPayload)
        case thermalState(ThermalStatePayload)
        case audioRoute(AudioRoutePayload)
        case displayTopology(DisplayTopologyPayload)
        case bluetoothBattery(BluetoothBatteryPayload)
        case networkQuality(NetworkQualityPayload)
        case notificationEvent(NotificationEventPayload)
        case diskHygiene(DiskHygienePayload)

        private enum CodingKeys: String, CodingKey {
            case type
            case appFocus, windowFocus, inputMetrics, browserActivity
            case hardwareStatus, idleSession, locationPing, syncResult
            case sessionEvent, cameraMicState, nowPlaying, networkContext
            case clipboardMetric, focusModeState, appLifecycle, mailStats
            case receipt
            case gitVelocity, cliCommand, thermalState, audioRoute
            case displayTopology, bluetoothBattery, networkQuality
            case notificationEvent, diskHygiene
        }

        private enum PayloadType: String, Codable {
            case appFocus, windowFocus, inputMetrics, browserActivity
            case hardwareStatus, idleSession, locationPing, syncResult
            case sessionEvent, cameraMicState, nowPlaying, networkContext
            case clipboardMetric, focusModeState, appLifecycle, mailStats
            case receipt
            case gitVelocity, cliCommand, thermalState, audioRoute
            case displayTopology, bluetoothBattery, networkQuality
            case notificationEvent, diskHygiene
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
            case .sessionEvent:    self = .sessionEvent(try c.decode(SessionEventPayload.self, forKey: .sessionEvent))
            case .cameraMicState:  self = .cameraMicState(try c.decode(CameraMicPayload.self, forKey: .cameraMicState))
            case .nowPlaying:      self = .nowPlaying(try c.decode(NowPlayingPayload.self, forKey: .nowPlaying))
            case .networkContext:  self = .networkContext(try c.decode(NetworkContextPayload.self, forKey: .networkContext))
            case .clipboardMetric: self = .clipboardMetric(try c.decode(ClipboardMetricPayload.self, forKey: .clipboardMetric))
            case .focusModeState:  self = .focusModeState(try c.decode(FocusModePayload.self, forKey: .focusModeState))
            case .appLifecycle:    self = .appLifecycle(try c.decode(AppLifecyclePayload.self, forKey: .appLifecycle))
            case .mailStats:       self = .mailStats(try c.decode(MailStatsPayload.self, forKey: .mailStats))
            case .receipt:         self = .receipt(try c.decode(ReceiptPayload.self, forKey: .receipt))
            case .gitVelocity:     self = .gitVelocity(try c.decode(GitVelocityPayload.self, forKey: .gitVelocity))
            case .cliCommand:      self = .cliCommand(try c.decode(CLICommandPayload.self, forKey: .cliCommand))
            case .thermalState:    self = .thermalState(try c.decode(ThermalStatePayload.self, forKey: .thermalState))
            case .audioRoute:      self = .audioRoute(try c.decode(AudioRoutePayload.self, forKey: .audioRoute))
            case .displayTopology: self = .displayTopology(try c.decode(DisplayTopologyPayload.self, forKey: .displayTopology))
            case .bluetoothBattery:self = .bluetoothBattery(try c.decode(BluetoothBatteryPayload.self, forKey: .bluetoothBattery))
            case .networkQuality:  self = .networkQuality(try c.decode(NetworkQualityPayload.self, forKey: .networkQuality))
            case .notificationEvent:self = .notificationEvent(try c.decode(NotificationEventPayload.self, forKey: .notificationEvent))
            case .diskHygiene:     self = .diskHygiene(try c.decode(DiskHygienePayload.self, forKey: .diskHygiene))
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
            case .sessionEvent(let p):    try c.encode(PayloadType.sessionEvent, forKey: .type);    try c.encode(p, forKey: .sessionEvent)
            case .cameraMicState(let p):  try c.encode(PayloadType.cameraMicState, forKey: .type);  try c.encode(p, forKey: .cameraMicState)
            case .nowPlaying(let p):      try c.encode(PayloadType.nowPlaying, forKey: .type);      try c.encode(p, forKey: .nowPlaying)
            case .networkContext(let p):  try c.encode(PayloadType.networkContext, forKey: .type);  try c.encode(p, forKey: .networkContext)
            case .clipboardMetric(let p): try c.encode(PayloadType.clipboardMetric, forKey: .type); try c.encode(p, forKey: .clipboardMetric)
            case .focusModeState(let p):  try c.encode(PayloadType.focusModeState, forKey: .type);  try c.encode(p, forKey: .focusModeState)
            case .appLifecycle(let p):    try c.encode(PayloadType.appLifecycle, forKey: .type);    try c.encode(p, forKey: .appLifecycle)
            case .mailStats(let p):       try c.encode(PayloadType.mailStats, forKey: .type);       try c.encode(p, forKey: .mailStats)
            case .receipt(let p):         try c.encode(PayloadType.receipt, forKey: .type);         try c.encode(p, forKey: .receipt)
            case .gitVelocity(let p):     try c.encode(PayloadType.gitVelocity, forKey: .type);     try c.encode(p, forKey: .gitVelocity)
            case .cliCommand(let p):      try c.encode(PayloadType.cliCommand, forKey: .type);      try c.encode(p, forKey: .cliCommand)
            case .thermalState(let p):    try c.encode(PayloadType.thermalState, forKey: .type);    try c.encode(p, forKey: .thermalState)
            case .audioRoute(let p):      try c.encode(PayloadType.audioRoute, forKey: .type);      try c.encode(p, forKey: .audioRoute)
            case .displayTopology(let p): try c.encode(PayloadType.displayTopology, forKey: .type); try c.encode(p, forKey: .displayTopology)
            case .bluetoothBattery(let p):try c.encode(PayloadType.bluetoothBattery, forKey: .type);try c.encode(p, forKey: .bluetoothBattery)
            case .networkQuality(let p):  try c.encode(PayloadType.networkQuality, forKey: .type);  try c.encode(p, forKey: .networkQuality)
            case .notificationEvent(let p):try c.encode(PayloadType.notificationEvent, forKey: .type);try c.encode(p, forKey: .notificationEvent)
            case .diskHygiene(let p):     try c.encode(PayloadType.diskHygiene, forKey: .type);     try c.encode(p, forKey: .diskHygiene)
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
    var secureInputSuppressed: Bool = false  // true when macOS Secure Input hid keyDown events
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

// MARK: - v0.4.0 Context Pack payloads

/// Screen lock/unlock, system sleep/wake, lid open/close.
struct SessionEventPayload: Codable {
    enum SessionEventType: String, Codable {
        case screenLocked, screenUnlocked
        case systemSleep, systemWake
        case lidClosed, lidOpened
    }
    let observedAt: Date
    let event: SessionEventType
}

/// Camera / microphone in-use state. Metadata only: which device class is live,
/// never any audio/video content.
struct CameraMicPayload: Codable {
    let observedAt: Date
    let cameraActive: Bool
    let microphoneActive: Bool
    /// Frontmost app at observation time — heuristic for "who's in the call".
    let frontmostApp: String?
}

/// Now Playing metadata via MediaRemote (read-only, private framework).
struct NowPlayingPayload: Codable {
    let observedAt: Date
    let appName: String?        // e.g. "Spotify", "Music"
    let title: String?
    let artist: String?
    let isPlaying: Bool
}

/// Wi-Fi context. BSSID is stored hashed (SHA-256) so the network is
/// identifiable day-to-day but not mappable to a physical AP database.
struct NetworkContextPayload: Codable {
    let observedAt: Date
    let ssid: String?
    let bssidHash: String?
    let rssi: Int?              // signal strength dBm
    let onVPN: Bool
}

/// Clipboard METADATA ONLY — change count deltas, UTI types, byte sizes.
/// The copied content is never read or stored.
struct ClipboardMetricPayload: Codable {
    let observedAt: Date
    let copiesInInterval: Int       // changeCount delta since last poll
    let contentTypes: [String]      // e.g. ["public.utf8-plain-text"], current item only
    let byteSize: Int?              // size of current item, nil if unknown
}

/// macOS Focus (Do Not Disturb etc.) state.
struct FocusModePayload: Codable {
    let observedAt: Date
    let focusActive: Bool
    let authorized: Bool        // false if Intents Focus permission not granted
}

/// App launched / quit lifecycle events.
struct AppLifecyclePayload: Codable {
    enum LifecycleEvent: String, Codable { case launched, terminated }
    let observedAt: Date
    let appName: String
    let bundleID: String?
    let event: LifecycleEvent
}

/// Mail.app statistics via AppleScript. Counts by default; sender names only
/// when the `macsync.mailSenderNames` user default is enabled.
struct MailStatsPayload: Codable {
    let observedAt: Date
    let unreadCount: Int
    let receivedToday: Int
    let sentToday: Int
    let topSenders: [String]?   // nil unless sender-name logging is enabled
    let success: Bool
    let errorMessage: String?
}

// MARK: - v0.5.0 Receipts & Spending

/// Category of an expense. `businessDeductible` is the default tax hint; the
/// user can override it per category in Settings (and per receipt in the UI).
enum ReceiptCategory: String, CaseIterable, Codable, Identifiable {
    case dining, groceries, software, subscriptions, travel, transport
    case utilities, health, education, shopping, business, other, unknown
    var id: String { rawValue }

    var label: String {
        switch self {
        case .dining: "Dining"; case .groceries: "Groceries"
        case .software: "Software"; case .subscriptions: "Subscriptions"
        case .travel: "Travel"; case .transport: "Transport"
        case .utilities: "Utilities"; case .health: "Health"
        case .education: "Education"; case .shopping: "Shopping"
        case .business: "Business"; case .other: "Other"
        case .unknown: "Needs review"
        }
    }

    /// Default business-deductibility hint (overridable per category).
    var businessDeductible: Bool {
        switch self {
        case .software, .subscriptions, .travel, .utilities,
             .business, .education, .transport: return true
        default: return false
        }
    }

    var colorHex: String {
        switch self {
        case .dining: "#FFD166"; case .groceries: "#63E6BE"
        case .software: "#5B8CFF"; case .subscriptions: "#7BDFF2"
        case .travel: "#C77DFF"; case .transport: "#FF8A5B"
        case .utilities: "#FF6B8A"; case .health: "#9AA0B5"
        case .education: "#FF9F1C"; case .shopping: "#F4D35E"
        case .business: "#2EC4B6"; case .other: "#9AA0B5"
        case .unknown: "#8D99AE"
        }
    }

    var icon: String {
        switch self {
        case .dining: "fork.knife"; case .groceries: "cart"
        case .software: "chevron.left.forwardslash.chevron.right"; case .subscriptions: "repeat"
        case .travel: "airplane"; case .transport: "car"
        case .utilities: "bolt"; case .health: "heart"
        case .education: "graduationcap"; case .shopping: "bag"
        case .business: "briefcase"; case .other: "square.grid.2x2"
        case .unknown: "questionmark"
        }
    }

    static var assignable: [ReceiptCategory] { allCases.filter { $0 != .unknown } }
}

/// One tracked expense. **Only parsed fields are stored — never the email
/// body.** `source` is "mail" or "manual"; `mailMessageID` enables dedup.
struct ReceiptPayload: Codable, Identifiable {
    let id: UUID
    let merchant: String
    let amount: Decimal
    let currency: String
    let cardLast4: String?
    let category: ReceiptCategory
    let transactionDate: Date
    let capturedAt: Date
    let source: String        // "mail" | "manual"
    let mailMessageID: String?
    let confidence: Double    // 0...1 parser reliability
    let needsReview: Bool     // low confidence → ask the user to confirm
    let notes: String?

    var amountDouble: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

// MARK: - Novel Telemetry Suite (v0.6.0)

/// Phase 1: Git repository and velocity telemetry.
struct GitVelocityPayload: Codable {
    let observedAt: Date
    let repoName: String
    let branch: String
    let uncommittedDiffLines: Int
    let commitsToday: Int
}

/// Phase 1: CLI command and debugging telemetry.
struct CLICommandPayload: Codable {
    let observedAt: Date
    let commandName: String
    let exitCode: Int
    let durationMs: Int
    let isBuildOrTest: Bool
}

/// Phase 1: Thermal state & CPU throttling.
struct ThermalStatePayload: Codable {
    let observedAt: Date
    let thermalLevel: String
    let cpuUsagePercent: Double
    let isThrottled: Bool
}

/// Phase 2: Audio output route and acoustic flow.
struct AudioRoutePayload: Codable {
    let observedAt: Date
    let outputDeviceName: String
    let isAirPods: Bool
    let isHeadphones: Bool
    let volume: Float
}

/// Phase 2: Display topology & external monitors.
struct DisplayTopologyPayload: Codable {
    let observedAt: Date
    let screenCount: Int
    let hasExternalDisplay: Bool
    let primaryResolution: String
}

/// Phase 2: Bluetooth peripheral battery levels.
struct BluetoothDeviceBattery: Codable {
    let name: String
    let batteryPercent: Int
}

struct BluetoothBatteryPayload: Codable {
    let observedAt: Date
    let devices: [BluetoothDeviceBattery]
}

/// Phase 3: Network quality & latency.
struct NetworkQualityPayload: Codable {
    let observedAt: Date
    let pingMs: Double
    let packetLossPercent: Double
    let qualityGrade: String
}

/// Phase 3: Notification interruption events.
struct NotificationEventPayload: Codable {
    let observedAt: Date
    let sourceApp: String
}

/// Phase 3: Disk hygiene & Downloads folder cruft.
struct DiskHygienePayload: Codable {
    let observedAt: Date
    let downloadsSizeGB: Double
    let staleInstallerCount: Int
    let freeDiskSpaceGB: Double
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

enum SyncFormat {
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
