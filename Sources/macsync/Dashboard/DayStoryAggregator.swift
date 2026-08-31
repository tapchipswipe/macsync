import Foundation

enum StoryChapterType: String, Codable {
    case deepWork = "Deep Work"
    case meeting = "In-Call Meeting"
    case purchase = "Purchase"
    case research = "Web Research"
    case focus = "Focus Session"
    case leisure = "Leisure & Media"
    case breakOrIdle = "Away / Idle"

    var icon: String {
        switch self {
        case .deepWork: return "sparkles"
        case .meeting: return "video.fill"
        case .purchase: return "creditcard.fill"
        case .research: return "safari.fill"
        case .focus: return "bolt.fill"
        case .leisure: return "play.tv.fill"
        case .breakOrIdle: return "pause.circle.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .deepWork: return "#5B8CFF"  // Blue
        case .meeting: return "#FF6B8A"   // Coral
        case .purchase: return "#63E6BE"  // Mint Green
        case .research: return "#A78BFA"  // Purple
        case .focus: return "#F59E0B"     // Amber
        case .leisure: return "#EC4899"   // Pink
        case .breakOrIdle: return "#94A3B8" // Slate
        }
    }
}

struct StoryChapter: Identifiable, Codable {
    var id: UUID = UUID()
    let startTime: Date
    let endTime: Date
    let type: StoryChapterType
    let title: String
    let summary: String
    let details: [String]
    let locationOrWifi: String?
    let spendAmount: Decimal?
    let cardNickname: String?

    var timeRangeLabel: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: startTime)) – \(f.string(from: endTime))"
    }

    var durationMinutes: Int {
        max(1, Int(endTime.timeIntervalSince(startTime) / 60))
    }
}

struct DayStory {
    let date: Date
    let chapters: [StoryChapter]
    let totalDeepWorkMinutes: Int
    let totalMeetingMinutes: Int
    let totalDaySpend: Decimal

    static let empty = DayStory(date: Date(), chapters: [], totalDeepWorkMinutes: 0, totalMeetingMinutes: 0, totalDaySpend: 0)
}

enum DayStoryAggregator {

    /// Synthesizes multi-stream events (apps, meetings, receipts, location) into structured Day Chapters.
    static func buildStory(events: [TrackerEvent], forDate targetDate: Date = Date()) -> DayStory {
        guard !events.isEmpty else { return .empty }

        let sorted = events.sorted { $0.ts < $1.ts }
        var chapters: [StoryChapter] = []

        var deepWorkMins = 0
        var meetingMins = 0
        var totalSpend: Decimal = 0

        // Extract receipts for the day
        var dayReceipts: [ReceiptPayload] = []
        for e in sorted {
            if case .receipt(let r) = e.payload {
                dayReceipts.append(r)
                totalSpend += r.amount
            }
        }

        // 1. Convert receipts into discrete timeline moments
        for r in dayReceipts {
            let cardName = CardPortfolio.displayName(for: r.cardLast4)
            let noteInfo = r.notes.map { " (\($0))" } ?? ""
            let chapter = StoryChapter(
                startTime: r.transactionDate,
                endTime: r.transactionDate.addingTimeInterval(300), // 5 min moment
                type: .purchase,
                title: "\(r.merchant) · \(SpendFormat.amount(r.amount, currency: r.currency))",
                summary: "\(r.category.label.capitalized) on \(cardName)\(noteInfo)",
                details: ["Card: \(cardName)", "Category: \(r.category.label)"],
                locationOrWifi: nil,
                spendAmount: r.amount,
                cardNickname: cardName
            )
            chapters.append(chapter)
        }

        // 2. Synthesize App & Window sessions
        var currentApp: String? = nil
        var sessionStart: Date = sorted.first!.ts
        var sessionTitles: Set<String> = []

        for e in sorted {
            if case .windowFocus(let w) = e.payload {
                if currentApp == nil {
                    currentApp = w.appName
                    sessionStart = e.ts
                    if let title = w.windowTitle, !title.isEmpty { sessionTitles.insert(title) }
                } else if currentApp == w.appName {
                    if let title = w.windowTitle, !title.isEmpty { sessionTitles.insert(title) }
                } else {
                    // Session ended
                    let duration = e.ts.timeIntervalSince(sessionStart)
                    if duration >= 180 { // At least 3 minutes to count as a chapter
                        let appName = currentApp ?? "App"
                        let type = classifyAppType(appName)
                        let mins = Int(duration / 60)
                        if type == .deepWork { deepWorkMins += mins }

                        let detailsList = Array(sessionTitles.prefix(3))
                        let chapter = StoryChapter(
                            startTime: sessionStart,
                            endTime: e.ts,
                            type: type,
                            title: "\(appName) · \(mins)m",
                            summary: "\(type.rawValue) in \(appName)",
                            details: detailsList,
                            locationOrWifi: nil,
                            spendAmount: nil,
                            cardNickname: nil
                        )
                        chapters.append(chapter)
                    }

                    currentApp = w.appName
                    sessionStart = e.ts
                    sessionTitles.removeAll()
                    if let title = w.windowTitle, !title.isEmpty { sessionTitles.insert(title) }
                }
            } else if case .cameraMicState(let cm) = e.payload {
                if cm.cameraActive || cm.microphoneActive {
                    meetingMins += 5
                }
            }
        }

        // Flush last active app session if long enough
        if let app = currentApp, let lastEvent = sorted.last {
            let duration = lastEvent.ts.timeIntervalSince(sessionStart)
            if duration >= 180 {
                let type = classifyAppType(app)
                let mins = Int(duration / 60)
                if type == .deepWork { deepWorkMins += mins }
                let chapter = StoryChapter(
                    startTime: sessionStart,
                    endTime: lastEvent.ts,
                    type: type,
                    title: "\(app) · \(mins)m",
                    summary: "\(type.rawValue) in \(app)",
                    details: Array(sessionTitles.prefix(3)),
                    locationOrWifi: nil,
                    spendAmount: nil,
                    cardNickname: nil
                )
                chapters.append(chapter)
            }
        }

        // Sort all synthesized chapters chronologically
        chapters.sort { $0.startTime < $1.startTime }

        return DayStory(
            date: targetDate,
            chapters: chapters,
            totalDeepWorkMinutes: deepWorkMins,
            totalMeetingMinutes: meetingMins,
            totalDaySpend: totalSpend
        )
    }

    private static func classifyAppType(_ appName: String) -> StoryChapterType {
        let name = appName.lowercased()
        if name.contains("xcode") || name.contains("cursor") || name.contains("terminal") ||
           name.contains("code") || name.contains("sublime") || name.contains("intellij") ||
           name.contains("pycharm") || name.contains("figma") || name.contains("linear") ||
           name.contains("notion") || name.contains("slack") {
            return .deepWork
        }
        if name.contains("zoom") || name.contains("meet") || name.contains("teams") || name.contains("facetime") {
            return .meeting
        }
        if name.contains("safari") || name.contains("chrome") || name.contains("arc") || name.contains("brave") || name.contains("firefox") {
            return .research
        }
        if name.contains("spotify") || name.contains("music") || name.contains("tv") || name.contains("youtube") {
            return .leisure
        }
        return .focus
    }
}
