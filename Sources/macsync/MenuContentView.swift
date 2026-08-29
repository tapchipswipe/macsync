import SwiftUI

// MARK: - Tabs (Vorssaint-style icon tab strip)

enum MenuTab: String, CaseIterable, Identifiable {
    case today, apps, insights, sync, settings
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today:    return "waveform.path.ecg"
        case .apps:     return "square.grid.2x2"
        case .insights: return "sparkles"
        case .sync:     return "icloud"
        case .settings: return "gearshape"
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var updater = UpdateChecker.shared
    @State private var tab: MenuTab = .today

    @AppStorage("macsync.nightPauseEnabled") private var nightPause = false
    @AppStorage("macsync.zipArchives") private var zipArchives = true
    @AppStorage("macsync.encryptArchives") private var encryptArchives = false

    var body: some View {
        VStack(spacing: 0) {
            header
            tabStrip
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .today:    todayTab
                    case .apps:     appsTab
                    case .insights: insightsTab
                    case .sync:     syncTab
                    case .settings: settingsTab
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            // FIX: explicitly bound the scroll area. An unbounded ScrollView whose
            // children contain GeometryReader resolves to zero height in a
            // .window MenuBarExtra — this is what made every tab look blank.
            .frame(minHeight: 300, maxHeight: 460)
            footer
        }
        .frame(width: 360)
        .background(AppTheme.window)
        .preferredColorScheme(.dark)
        .onAppear {
            appState.refreshPermissionStatus()
            appState.refreshLaunchAtLoginStatus()
            appState.refreshStats()
            appState.refreshAggregation()
            appState.nextScheduledSync = appState.scheduler.nextScheduledSync
        }
    }

    // MARK: - Header (centered mark + focus ring #1)

    private var header: some View {
        VStack(spacing: 4) {
            ZStack {
                // Focus score ring (#1) around the mark
                FocusRing(progress: Double(appState.stats.focusScore) / 100.0)
                    .frame(width: 56, height: 56)
                if appState.healthIsBad {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                        .offset(x: 24, y: -16)
                }
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 24, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.95))
            }
            Text("\(appState.stats.focusScore) · \(appState.stats.focusScoreLabel)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Text(appState.isTracking ? "recording" : "paused")
                .font(.system(size: 9, weight: .medium)).tracking(2)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    // MARK: - Icon tab strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(MenuTab.allCases) { t in
                Button { withAnimation(.spring(duration: 0.25)) { tab = t } } label: {
                    Image(systemName: t.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tab == t ? .white : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(tab == t ? AppTheme.accent.opacity(0.35) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - TODAY tab

    private var todayTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("TODAY")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                miniTile("keyboard", AppTheme.tileKey, "Keystrokes", "\(appState.stats.keystrokes)")
                miniTile("hand.tap", AppTheme.tileClick, "Clicks", "\(appState.stats.clicks)")
                miniTile("cursorarrow.motionlines", AppTheme.tileCursor, "Cursor", DashboardView.distanceText(appState.stats.cursorDistance))
                miniTile("clock", AppTheme.accent, "Active", "\(Int(appState.stats.activeMinutes))m")
            }
            if appState.secureInputSuppressed {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "lock.shield").font(.system(size: 11)).foregroundStyle(.orange)
                    Text("Keystrokes hidden by Secure Input (a password field is focused). Counts resume automatically.")
                        .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.orange.opacity(0.10)))
            }
            Button { openWindow(id: SceneID.dashboard) } label: {
                Label("Open Dashboard", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(AppTheme.accent).controlSize(.regular)
        }
    }

    private func miniTile(_ icon: String, _ tint: Color, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - APPS tab (+ per-app history #3)

    private var appsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("TOP APPS")
            let apps = Array(appState.stats.apps.prefix(5))
            if apps.isEmpty {
                Text("No focus captured yet — grant Accessibility in the Settings tab")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            } else {
                VStack(spacing: 4) {
                    ForEach(apps) { a in
                        // Tapping an app opens its day history in the Dashboard (#3).
                        Button { AppHistoryStore.shared.select(app: a.name); openWindow(id: SceneID.dashboard) } label: {
                            AppBarRow(app: a, maxSeconds: apps.first?.seconds ?? 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            sectionLabel("CONTEXT")
            let cats = appState.stats.categories
            if cats.isEmpty {
                Text("—").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
            } else {
                ContextRibbon(categories: cats)
                VStack(spacing: 6) {
                    ForEach(cats.prefix(5)) { c in
                        HStack(spacing: 8) {
                            Image(systemName: c.category.icon).font(.system(size: 10))
                                .foregroundStyle(Color(hex: c.category.colorHex)).frame(width: 16)
                            Text(c.category.label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text("\(Int(c.seconds / 60))m").font(.system(size: 10, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
            }
        }
    }

    // MARK: - INSIGHTS tab (#4)

    private var insightsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("INSIGHTS")
            if let anomaly = appState.stats.anomaly {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12)).foregroundStyle(.orange)
                    Text(anomaly).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.orange.opacity(0.12)))
            }
            let items = appState.stats.insights
            if items.isEmpty && appState.stats.anomaly == nil {
                Text("Nothing notable yet — keep using your Mac and macsync will spot patterns.")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkle").font(.system(size: 10)).foregroundStyle(AppTheme.accent)
                            Text(line).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.card))
                    }
                }
            }
            // Zombie-scroll meter (#5) surfaced here too
            if appState.stats.zombieSeconds > 120 {
                sectionLabel("PASSIVE TIME")
                HStack(spacing: 10) {
                    Image(systemName: "zzz").font(.system(size: 12)).foregroundStyle(AppTheme.tileScroll)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(appState.stats.zombieSeconds / 60))m with zero input")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                        Text("A window was focused but you were hands-off")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            }
        }
    }

    // MARK: - SYNC tab

    private var nextSyncText: String? {
        guard let next = appState.nextScheduledSync else { return nil }
        let f = DateFormatter(); f.timeStyle = .short
        return "Next automatic sync \(f.string(from: next))"
    }

    private var syncTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("ICLOUD SYNC")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    Image(systemName: syncIcon)
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(syncTint)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(syncTint.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncTitle).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white)
                        Text(syncDetail).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
                    }
                    Spacer()
                }
                if let nextText = nextSyncText {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
                        Text(nextText)
                            .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                if appState.missedDaysSynced > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(AppTheme.batteryGreen)
                        Text("Synced \(appState.missedDaysSynced) missed day(s)")
                            .font(.system(size: 10.5)).foregroundStyle(AppTheme.batteryGreen.opacity(0.9))
                    }
                }
                Button { appState.syncNow() } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent).controlSize(.regular)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            if updater.state == .available {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Update available").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        Text("Version \(updater.latestVersion ?? "") is ready").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Button("Get") { updater.openDownloadPage() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            }
        }
    }

    // MARK: - SETTINGS tab

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("PERMISSIONS")
            VStack(spacing: 0) {
                permRow(appState.accessibilityGranted, "Accessibility", "Counts keystrokes & clicks")
                Divider().background(.white.opacity(0.07))
                permRow(appState.screenRecordingGranted, "Screen Recording", "Reads window titles")
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            if !appState.accessibilityGranted || !appState.screenRecordingGranted {
                Button { appState.requestPermissions() } label: {
                    Label("Request Permissions", systemImage: "lock.open")
                        .font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent).controlSize(.regular)
            }
            sectionLabel("MENU BAR")
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Show active time in menu bar", isOn: Binding(
                    get: { appState.showMenuBarTime },
                    set: { appState.showMenuBarTime = $0 }
                ))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            sectionLabel("OPTIONS")
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Night pause (23:00 – 07:00)", isOn: $nightPause)
                    .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                Toggle("Zip daily archives", isOn: $zipArchives)
                    .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                Toggle("Encrypt archives (AES-256)", isOn: $encryptArchives)
                    .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { appState.toggleLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                if appState.launchAtLoginNeedsApproval {
                    Button("Approval needed — open Login Items") { appState.openLoginItemsSettings() }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.orange)
                }
                HStack {
                    Text(updateStatusText).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Button("Check") { updater.checkNow() }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(AppTheme.accent)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            sectionLabel("TRACKING")
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Record activity", isOn: Binding(
                    get: { appState.isTracking },
                    set: { _ in appState.toggleTracking() }
                ))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                HStack {
                    Button { appState.openDataFolder() } label: {
                        Label("Open Data Folder", systemImage: "folder").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
                    Spacer()
                    Button { appState.openOnboarding() } label: {
                        Text("Welcome…").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
        }
    }

    // MARK: - Footer (Vorssaint-style: two pill buttons)

    private var footer: some View {
        HStack(spacing: 10) {
            Button { appState.openOnboarding() } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FooterButtonStyle())
            Button { NSApplication.shared.terminate(nil) } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FooterButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Shared pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold)).tracking(1.4)
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func permRow(_ granted: Bool, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(granted ? AppTheme.batteryGreen : .red).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                Text(sub).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.batteryGreen)
            } else {
                Button("Fix") { appState.requestPermissions() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.vertical, 9)
    }

    private var syncIcon: String {
        appState.lastSyncSuccess ? "checkmark.icloud"
            : (appState.lastSyncDate == nil ? "icloud.slash" : "exclamationmark.icloud")
    }
    private var syncTint: Color { appState.lastSyncSuccess ? AppTheme.batteryGreen : .orange }
    private var syncTitle: String {
        if appState.missedDaysSynced > 0 { return "Synced \(appState.missedDaysSynced) missed day(s)" }
        return appState.lastSyncSuccess ? "Synced to iCloud" : "Sync pending"
    }
    private var syncDetail: String {
        if let d = appState.lastSyncDate {
            let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
            return appState.lastSyncSuccess ? "\(f.string(from: d)) · \(appState.lastSyncDetail)"
                                            : "Failed \(f.string(from: d)) · \(appState.lastSyncDetail)"
        }
        return "No sync yet — automatic at 23:59"
    }
    private var updateStatusText: String {
        switch updater.state {
        case .checking: "Checking for updates…"
        case .upToDate: "Up to date (v\(UpdateChecker.currentVersion()))"
        case .available: "v\(updater.latestVersion ?? "?") available"
        case .failed: "Update check failed"
        case .idle: ""
        }
    }
}

// MARK: - Focus ring (#1)

private struct FocusRing: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - App bar row (static width — replaces collapsing GeometryReader)

private struct AppBarRow: View {
    let app: AppUsage
    let maxSeconds: TimeInterval
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(app.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer()
                Text("\(Int(app.seconds / 60))m").font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            // Fixed 320pt container with proportional fill — never collapses.
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.07))
                Capsule().fill(AppTheme.accent)
                    .frame(width: max(4, 320 * CGFloat(app.seconds / max(maxSeconds, 1))))
            }
            .frame(width: 320, height: 5)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

// MARK: - Context ribbon (fixed container)

private struct ContextRibbon: View {
    let categories: [CategoryUsage]
    var body: some View {
        let total = max(categories.reduce(TimeInterval(0)) { $0 + $1.seconds }, 1)
        HStack(spacing: 2) {
            ForEach(categories) { c in
                let w = max(6, 320 * CGFloat(c.seconds / total))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: c.category.colorHex))
                    .frame(width: w, height: 10)
            }
        }
        .frame(width: 320, alignment: .leading)
    }
}

// MARK: - App history store (#3)

/// Cross-scene selection so tapping a Top-Apps row can filter the Dashboard.
@MainActor
final class AppHistoryStore: ObservableObject {
    static let shared = AppHistoryStore()
    @Published var selectedApp: String?
    func select(app: String) { selectedApp = app }
    func clear() { selectedApp = nil }
}

// MARK: - Footer button style

private struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.5 : 0.85))
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.04 : 0.07))
            )
    }
}

private struct PulseModifier: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 0.25 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

enum SceneID {
    static let dashboard = "dashboard"
}
