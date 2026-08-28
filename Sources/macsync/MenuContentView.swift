import SwiftUI

struct MenuContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    @AppStorage("macsync.nightPauseEnabled") private var nightPause = false
    @AppStorage("macsync.zipArchives") private var zipArchives = true
    @AppStorage("macsync.encryptArchives") private var encryptArchives = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statGrid
                    focusBars
                    Divider()
                    syncCard
                    Divider()
                    permissionsCard
                    Divider()
                    settingsCard
                }
                .padding(14)
            }
            footer
        }
        .frame(width: 372)
        .onAppear {
            appState.refreshPermissionStatus()
            appState.refreshLaunchAtLoginStatus()
            appState.refreshStats()
            appState.refreshAggregation()
            appState.nextScheduledSync = appState.scheduler.nextScheduledSync
        }
    }

    // MARK: - Header
    private var header: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(.ultraThinMaterial)
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("macsync").font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(appState.isTracking ? "Tracking your day" : "Paused")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if appState.isTracking {
                    HStack(spacing: 5) {
                        Circle().fill(AppTheme.batteryGreen).frame(width: 7, height: 7)
                            .modifier(PulseModifier())
                        Text("LIVE").font(.system(size: 10, weight: .bold)).tracking(1)
                            .foregroundStyle(AppTheme.batteryGreen)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
    }

    // MARK: - Stat tiles
    private var statGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            miniTile("keyboard", AppTheme.tileKey, "Keystrokes", "\(appState.stats.keystrokes)")
            miniTile("hand.tap", AppTheme.tileClick, "Clicks", "\(appState.stats.clicks)")
            miniTile("scope", AppTheme.tileCursor, "Cursor", DashboardView.distanceText(appState.stats.cursorDistance))
            miniTile("clock", AppTheme.accent, "Active", "\(Int(appState.stats.activeMinutes))m")
        }
    }

    private func miniTile(_ icon: String, _ tint: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 15, weight: .bold, design: .rounded))
                Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - Insight / focus
    private var focusBars: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP APPS")
                .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                .foregroundStyle(.secondary)
            let apps = Array(appState.stats.apps.prefix(3))
            let total = max(apps.reduce(TimeInterval(0)) { $0 + $1.seconds }, 1)
            if apps.isEmpty {
                Text("No focus captured yet — grant Accessibility")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            ForEach(apps) { a in
                HStack(spacing: 10) {
                    Text(String(a.name.prefix(16)))
                        .font(.system(size: 12)).frame(width: 120, alignment: .leading).lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.08))
                            Capsule().fill(AppTheme.accent)
                                .frame(width: geo.size.width * CGFloat(a.seconds / total))
                        }
                    }
                    .frame(height: 6)
                    Text("\(Int(a.seconds / 60))m")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
            if let insight = appState.stats.topInsight {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10)).foregroundStyle(AppTheme.accent)
                    Text(insight).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.accent.opacity(0.08)))
            }
        }
    }

// MARK: - Sync
    private var syncCard: some View {
        HStack(spacing: 10) {
            Image(systemName: syncIcon)
                .foregroundStyle(syncTint)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(syncTint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(syncTitle).font(.system(size: 12, weight: .semibold))
                Text(syncDetail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button("Sync") { appState.syncNow() }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent).controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - Permissions + actions
    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                permissionDot(appState.accessibilityGranted, "Accessibility")
                permissionDot(appState.screenRecordingGranted, "Screen Rec.")
                Spacer()
                Button("Welcome…") { appState.openOnboarding() }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(AppTheme.accent)
            }
            HStack(spacing: 10) {
                Button { openWindow(id: SceneID.dashboard) } label: {
                    Label("Open Dashboard", systemImage: "chart.xyaxis.line").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent)
                Button { appState.openDataFolder() } label: {
                    Label("Data", systemImage: "folder").labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - Settings (#6 #9 #17)
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SETTINGS")
                .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                .foregroundStyle(.secondary)
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
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - Footer
    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit macsync")
                    Spacer()
                    Text("⌘Q").foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    // MARK: - Helpers
    private func permissionDot(_ granted: Bool, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(granted ? AppTheme.batteryGreen : .red).frame(width: 7, height: 7)
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
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
