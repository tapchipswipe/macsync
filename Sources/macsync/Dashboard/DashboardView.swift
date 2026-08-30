import Charts
import SwiftUI

enum DashRange: String, CaseIterable, Identifiable {
    case today = "Today", week = "Week", month = "Month"
    var id: String { rawValue }
    var daysBack: Int { self == .week ? 7 : 30 }
}

struct ClipboardPoint: Identifiable {
    let id = UUID()
    let hour: Int
    let copies: Int
}

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var appHistory = AppHistoryStore.shared
    @State private var range: DashRange = .today
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("macsync")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: $range) {
                    ForEach(DashRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            Divider()
            ScrollView {
                content
                    .padding(24)
            }
        }
        .frame(minWidth: 860, minHeight: 640)
        .background(AppTheme.window.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch range {
        case .today:
            let s = appState.stats
            let todayEvents = DataStore.shared.events(forDay: SyncFormat.dayString())
            VStack(spacing: 22) {
                if let app = appHistory.selectedApp { appFilterBanner(app, stats: s) }
                hero(s)
                meetingIndicator(todayEvents, stats: s)
                metricGrid(s)
                if !s.activity.isEmpty { activityChart(s) }
                if !s.categories.isEmpty { categoriesCard(s) }
                if let app = appHistory.selectedApp {
                    appHistoryCard(app, stats: s)
                } else if !s.apps.isEmpty {
                    appsCard(s)
                }
                contextSection(s, events: todayEvents)
                if !appState.spendToday.receipts.isEmpty { spendSection(appState.spendToday) }
                insightsCard(s)
                hardwareRow(s)
            }
        case .week:
            periodSection(daysBack: 7, title: "LAST 7 DAYS")
        case .month:
            periodSection(daysBack: 30, title: "LAST 30 DAYS")
        }
    }

    // MARK: - Hero
    private func hero(_ s: TodayStats) -> some View {
        HStack(alignment: .center, spacing: 22) {
            ActivityRing(progress: max(0.001, min(1, s.activeMinutes / 480)),
                         color: AppTheme.accent, size: 96, line: 9)
                .overlay(alignment: .center) {
                    Text("\(Int(s.activeMinutes))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 5) {
                Text("TODAY'S FOCUS")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.7)
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(Int(s.activeMinutes)) minutes active")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    statChip("\(s.keystrokes)", "keys")
                    statChip("\(s.clicks)", "clicks")
                    statChip(Self.distanceText(s.cursorDistance), "moved")
                }
                Text(Self.timeFmt.string(from: Date()))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(22)
        .background(
            LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.18))
                .padding(18)
        }
    }

    private func statChip(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 11)).opacity(0.7)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.14)))
        .foregroundStyle(.white)
    }
}

// MARK: - Sections
extension DashboardView {

    static func distanceText(_ pts: Double) -> String {
        let meters = pts / 72.0 * 0.0254
        if meters < 1000 { return "\(Int(meters))m" }
        return String(format: "%.1fkm", meters / 1000.0)
    }

    func metricGrid(_ s: TodayStats) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            tile("keyboard", AppTheme.tileKey, "Keys", "\(s.keystrokes)")
            tile("hand.tap", AppTheme.tileClick, "Clicks", "\(s.clicks)")
            tile("arrow.up.arrow.down", AppTheme.tileScroll, "Scrolls", "\(s.scrolls)")
            tile("scope", AppTheme.tileCursor, "Cursor", Self.distanceText(s.cursorDistance))
        }
    }

    private func tile(_ icon: String, _ tint: Color, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            Text(value).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(AppTheme.card))
    }

    func activityChart(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ACTIVITY", "Keystrokes per minute")
            Chart(s.activity) { pt in
                BarMark(x: .value("Minute", pt.minute), y: .value("Keys", pt.keystrokes))
                    .foregroundStyle(AppTheme.accent.opacity(0.85))
                    .cornerRadius(2)
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 8)) { _ in
                AxisValueLabel().foregroundStyle(.white.opacity(0.5)) } }
            .frame(height: 150)
        }
        .cardStyle()
    }

    func appsCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("TOP APPS", "Focus time by application")
            let total = max(s.apps.reduce(TimeInterval(0)) { $0 + $1.seconds }, 1)
            VStack(spacing: 10) {
                ForEach(s.apps.prefix(6)) { a in
                    HStack(spacing: 12) {
                        Text(String(a.name.prefix(20)))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 150, alignment: .leading).lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.08))
                                Capsule().fill(AppTheme.accent)
                                    .frame(width: geo.size.width * CGFloat(a.seconds / total))
                            }
                        }
                        .frame(height: 8)
                        Text("\(Int(a.seconds / 60))m")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: Per-app history (#3)

    /// Banner shown at the top of Today when a specific app was picked in the menu.
    private func appFilterBanner(_ app: String, stats s: TodayStats) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 15)).foregroundStyle(AppTheme.accent)
            Text("Showing focus history for **\(app)**")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
            Spacer()
            Button("Clear") { appHistory.clear() }
                .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.accent.opacity(0.12)))
    }

    /// Hour-by-hour focus timeline for one app, built from today's appFocus events.
    private func appHistoryCard(_ app: String, stats s: TodayStats) -> some View {
        let events = DataStore.shared.events(forDay: SyncFormat.dayString())
        // Minutes of the day (0..<1440) during which this app held focus.
        var minutes = Array(repeating: 0.0, count: 24)
        let cal = Calendar.current
        for e in events {
            if case .appFocus(let p) = e.payload, p.appName == app {
                let hour = cal.component(.hour, from: e.ts)
                minutes[hour] += p.durationSeconds / 60.0
            }
        }
        let points = minutes.enumerated().map { (h: $0.offset, mins: $0.element) }
        let totalSec = s.apps.first(where: { $0.name == app })?.seconds ?? 0
        let peak = points.max(by: { $0.mins < $1.mins })

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle(app.uppercased(), "Focus time by hour today")
            HStack(spacing: 14) {
                Label("\(Int(totalSec / 60))m focused", systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(AppTheme.accent)
                if let peak, peak.mins > 0 {
                    Label("Peak \(String(format: "%02d:00", peak.h)) · \(Int(peak.mins))m", systemImage: "chart.bar.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                }
            }
            Chart(points, id: \.h) { p in
                BarMark(x: .value("Hour", p.h), y: .value("Minutes", p.mins))
                    .foregroundStyle(AppTheme.accent.opacity(0.9))
                    .cornerRadius(2)
            }
            .chartXAxis { AxisMarks(values: .stride(by: 3)) { v in
                AxisValueLabel { if let h = v.as(Int.self) { Text(String(format: "%02d", h)).foregroundStyle(.white.opacity(0.5)) } } } }
            .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(.white.opacity(0.5)) } }
            .frame(height: 140)
        }
        .cardStyle()
    }

    // MARK: Categories (#3)
    func categoriesCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CONTEXT", "Where your time went, by category")
            let total = max(s.categories.reduce(TimeInterval(0)) { $0 + $1.seconds }, 1)
            VStack(spacing: 10) {
                ForEach(s.categories.prefix(6)) { c in
                    HStack(spacing: 12) {
                        Label(c.category.label, systemImage: c.category.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 150, alignment: .leading).lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.08))
                                Capsule().fill(Color(hex: c.category.colorHex))
                                    .frame(width: geo.size.width * CGFloat(c.seconds / total))
                            }
                        }
                        .frame(height: 8)
                        Text("\(Int(c.seconds / 60))m")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: Insights (#4 #5 #18)
    func insightsCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("INSIGHTS", "What macsync recorded about your day")
            VStack(alignment: .leading, spacing: 9) {
                if let anomaly = s.anomaly {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12)).foregroundStyle(.orange)
                        Text(anomaly).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.orange.opacity(0.12)))
                }
                ForEach(Array(s.insights.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11)).foregroundStyle(AppTheme.accent)
                        Text(line).font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: Context pack cards (v0.4.0)

    func contextSection(_ s: TodayStats, events: [TrackerEvent]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            sessionsCard(s)
            mediaCard(s)
            clipboardCard(s, series: hourlyClipboard(events))
            mailCard(s)
        }
    }

    private func sessionsCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("SESSIONS", "Locks · wakes · launches")
            HStack(spacing: 18) {
                contextStat("lock.fill", AppTheme.tileMoon, "\(s.screenLockCount)", "locks")
                contextStat("sunrise.fill", AppTheme.tileNetwork, "\(s.wakeCount)", "wakes")
                contextStat("app.badge.fill", AppTheme.tileKey, "\(s.appLaunches.values.reduce(0, +))", "launches")
            }
            Spacer()
            HStack(spacing: 12) {
                Label("VPN", systemImage: s.onVPN == true ? "shield.fill" : "shield")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.tileNetwork)
                if let ssid = s.wifiSSID, !ssid.isEmpty {
                    Label(ssid, systemImage: "wifi")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .cardStyle()
    }

    private func mediaCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("MEDIA", "Playback · Now Playing")
            if let np = s.nowPlaying, np.isPlaying {
                HStack(spacing: 8) {
                    Image(systemName: "music.note").foregroundStyle(AppTheme.tileMedia)
                    Text(np.title ?? np.appName ?? "Playing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                }
                if let artist = np.artist, !artist.isEmpty {
                    Text("\(artist) · \(np.appName ?? "playing")")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
            } else if !s.mediaSeconds.isEmpty {
                Text("No active playback").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
            } else {
                Text("No media activity yet").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
            }
            let top = s.mediaSeconds.sorted { $0.value > $1.value }.prefix(3)
            if !top.isEmpty {
                ForEach(Array(top), id: \.key) { app, secs in
                    HStack(spacing: 8) {
                        Text(String(app.prefix(18))).font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                        Spacer()
                        Text("\(Int(secs / 60))m").font(.system(size: 12, design: .rounded))
                            .foregroundStyle(AppTheme.tileMedia)
                    }
                }
            }
            Spacer()
        }
        .cardStyle()
    }

    private func clipboardCard(_ s: TodayStats, series: [ClipboardPoint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("CLIPBOARD", "Copy/paste counts · metadata only")
            Label("\(s.clipboardCopies)", systemImage: "doc.on.clipboard")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if series.contains(where: { $0.copies > 0 }) {
                Chart(series) { p in
                    BarMark(x: .value("Hour", p.hour), y: .value("Copies", p.copies))
                        .foregroundStyle(AppTheme.tileMedia.opacity(0.85))
                        .cornerRadius(2)
                }
                .chartXAxis(.hidden)
                .frame(height: 42)
            } else {
                Text("no copy events yet").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .cardStyle()
    }

    private func mailCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("MAIL", "Inbox activity · counts only")
            if s.mailUnread != nil {
                HStack(spacing: 18) {
                    contextStat("envelope.badge", AppTheme.tileMail, "\(s.mailUnread ?? 0)", "unread")
                    contextStat("arrow.down.circle", AppTheme.tileMail, "\(s.mailReceivedToday ?? 0)", "received")
                    contextStat("arrow.up.circle", AppTheme.tileMail, "\(s.mailSentToday ?? 0)", "sent")
                }
                if let senders = s.mailTopSenders, !senders.isEmpty {
                    Text("Top senders: \(senders.prefix(3).joined(separator: ", "))")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            } else {
                Text("No Mail data yet").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .cardStyle()
    }

    private func contextStat(_ icon: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(value, systemImage: icon)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hourlyClipboard(_ events: [TrackerEvent]) -> [ClipboardPoint] {
        var hours = Array(repeating: 0, count: 24)
        let cal = Calendar.current
        for e in events {
            if case .clipboardMetric(let p) = e.payload {
                let h = cal.component(.hour, from: e.ts)
                hours[h] += p.copiesInInterval
            }
        }
        return hours.enumerated().map { ClipboardPoint(hour: $0.offset, copies: $0.element) }
    }

    /// Live meeting status from the most recent camera/mic sample (≤ 2.5 min old).
    private func liveMeeting(_ events: [TrackerEvent]) -> (active: Bool, app: String?) {
        let meetingApps: Set<String> = ["zoom", "teams", "meet", "slack", "facetime", "webex", "discord", "huddle"]
        var newest: (ts: Date, p: CameraMicPayload)?
        for e in events {
            if case .cameraMicState(let p) = e.payload, newest == nil || e.ts > newest!.ts {
                newest = (e.ts, p)
            }
        }
        guard let newest, Date().timeIntervalSince(newest.ts) < 150 else { return (false, nil) }
        var isMeeting = newest.p.cameraActive
        if newest.p.microphoneActive, let app = newest.p.frontmostApp {
            isMeeting = isMeeting || meetingApps.contains { app.lowercased().contains($0) }
        }
        return (isMeeting, newest.p.frontmostApp)
    }

    @ViewBuilder
    private func meetingIndicator(_ events: [TrackerEvent], stats s: TodayStats) -> some View {
        let live = liveMeeting(events)
        if live.active {
            HStack(spacing: 10) {
                Image(systemName: "video.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.tileMedia)
                Text("In a meeting\(live.app.map { " · \($0)" } ?? "")")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Spacer()
                Text("LIVE").font(.system(size: 10, weight: .heavy)).tracking(1.5)
                    .foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.red.opacity(0.75)))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.tileMedia.opacity(0.12)))
        } else if s.meetingMinutes >= 3 {
            HStack(spacing: 10) {
                Image(systemName: "mic.circle.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.tileMedia)
                Text("\(Int(s.meetingMinutes))m on calls today")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                if let focus = s.focusActive {
                    Text(focus ? "Focus on" : "Focus off").font(.system(size: 11))
                        .foregroundStyle(AppTheme.tileMoon)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.tileMedia.opacity(0.10)))
        }
    }

    // MARK: Period (#1)
    func periodSection(daysBack: Int, title: String) -> some View {
        let points = HistoryLoader.dayPoints(daysBack: daysBack, today: appState.stats)
        let archived = HistoryLoader.archivedEvents(daysBack: daysBack)
        let periodEvents = archived.flatMap { $0.events }
        let agg = TodayAggregator.compute(events: periodEvents, archived: [])
        let totalKeys = points.reduce(0) { $0 + $1.keystrokes }
        let totalMin = points.reduce(0.0) { $0 + $1.activeMinutes }
        let avgMin = points.isEmpty ? 0 : totalMin / Double(points.count)
        return VStack(spacing: 22) {
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold)).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    tile("keyboard", AppTheme.tileKey, "Total keys", "\(totalKeys)")
                    tile("clock", AppTheme.accent, "Active", "\(Int(totalMin / 60))h")
                    tile("calendar", AppTheme.tileClick, "Avg/day", "\(Int(avgMin))m")
                    tile("scope", AppTheme.tileCursor, "Cursor", Self.distanceText(agg.cursorDistance))
                }
            }
            if points.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("ACTIVE MINUTES PER DAY", "Across the selected range")
                    Chart(points) { p in
                        BarMark(x: .value("Day", p.date, unit: .day),
                                y: .value("Minutes", p.activeMinutes))
                            .foregroundStyle(AppTheme.accent.opacity(0.9))
                            .cornerRadius(3)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 8)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated)).foregroundStyle(.white.opacity(0.5)) } }
                    .frame(height: 170)
                }
                .cardStyle()
            }
            if !agg.categories.isEmpty { categoriesCard(agg) }
            if !agg.apps.isEmpty { appsCard(agg) }
            contextSection(agg, events: periodEvents)
            let periodSpend = SpendStats.calculate(events: periodEvents)
            if !periodSpend.receipts.isEmpty { spendSection(periodSpend) }
            insightsCard(agg)
        }
    }

    func spendSection(_ spend: SpendSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("SPENDING", "Tracked receipts")
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SpendFormat.amount(spend.total))
                        .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("total").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(SpendFormat.amount(spend.deductibleTotal))
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.batteryGreen)
                    Text("tax deductible").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                if spend.needsReviewCount > 0 {
                    Label("\(spend.needsReviewCount) needs review", systemImage: "exclamationmark.circle")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                }
            }
            if !spend.byCategory.isEmpty {
                HStack(alignment: .bottom, spacing: 14) {
                    let total = max(NSDecimalNumber(decimal: spend.total).doubleValue, 0.01)
                    ForEach(Array(spend.byCategory.sorted { $0.value > $1.value }.prefix(6)), id: \.key) { cat, amount in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: cat.colorHex))
                                .frame(width: 28, height: 8 + CGFloat(NSDecimalNumber(decimal: amount).doubleValue / total) * 56)
                            Text(cat.label).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                }
            }
        }
        .cardStyle()
    }

    func hardwareRow(_ s: TodayStats) -> some View {
        HStack(alignment: .top, spacing: 16) {
            batteryCard(s)
            if !s.pages.isEmpty { sitesCard(s) } else { cpuCard(s) }
        }
    }

    private func batteryCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Battery", systemImage: batteryIcon(s))
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                if let pct = s.batteryPercent {
                    Text("\(pct)%").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
            }
            if !s.batteryTrace.isEmpty {
                Chart(s.batteryTrace) { sample in
                    if let level = sample.level {
                        LineMark(x: .value("Time", sample.time), y: .value("Level", level))
                            .foregroundStyle(AppTheme.batteryGreen)
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .frame(height: 34)
            } else {
                Text("no battery samples yet")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }

    private func cpuCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System", systemImage: "cpu")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            HStack(spacing: 14) {
                gaugeChip("CPU", Int(s.cpuLoad))
                gaugeChip("RAM", Int(s.memoryPressure))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }

    private func gaugeChip(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().trim(from: 0, to: 0.75).stroke(.white.opacity(0.1), lineWidth: 5)
                Circle().trim(from: 0, to: 0.75 * CGFloat(min(value, 100)) / 100)
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Text("\(value)%").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
        }
    }

    private func sitesCard(_ s: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TOP SITES", "Viewed via Safari / Chrome")
            ForEach(s.pages.prefix(4)) { p in
                HStack(spacing: 8) {
                    Circle().fill(AppTheme.sitesAccent).frame(width: 6, height: 6)
                    Text(p.title).lineLimit(1)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("\(p.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }

    private func sectionTitle(_ text: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(.system(size: 11, weight: .semibold)).tracking(1.3)
                .foregroundStyle(.white.opacity(0.55))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
        }
    }

    private func batteryIcon(_ s: TodayStats) -> String {
        guard let _ = s.batteryPercent else { return "battery.0" }
        return s.batteryCharging == true ? "battery.100percent.bolt" : "battery.75percent"
    }
}

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.card))
    }
}
extension View { func cardStyle() -> some View { modifier(CardStyle()) } }

struct ActivityRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let line: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: line)
            Circle().trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 8)
        }
        .frame(width: size, height: size)
    }
}

enum AppTheme {
    static let accent = Color(red: 0.35, green: 0.62, blue: 1.0)
    static let accentDeep = Color(red: 0.40, green: 0.28, blue: 0.98)
    static let window = Color(red: 0.07, green: 0.08, blue: 0.11)
    static let card = Color.white.opacity(0.05)
    static let tileKey = Color(red: 0.55, green: 0.78, blue: 1.0)
    static let tileClick = Color(red: 1.0, green: 0.55, blue: 0.42)
    static let tileCursor = Color(red: 0.70, green: 1.0, blue: 0.60)
    static let tileScroll = Color(red: 0.92, green: 0.68, blue: 1.0)
    static let tileMedia = Color(red: 0.39, green: 0.90, blue: 0.75)   // teal
    static let tileNetwork = Color(red: 0.48, green: 0.87, blue: 0.95) // sky
    static let tileMail = Color(red: 1.0, green: 0.82, blue: 0.40)     // amber
    static let tileMoon = Color(red: 0.78, green: 0.49, blue: 1.0)     // violet
    static let batteryGreen = Color(red: 0.35, green: 0.85, blue: 0.55)
    static let sitesAccent = Color(red: 1.0, green: 0.80, blue: 0.40)
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255.0,
                  green: Double((v >> 8) & 0xFF) / 255.0,
                  blue: Double(v & 0xFF) / 255.0,
                  opacity: 1.0)
    }
}
