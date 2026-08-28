import SwiftUI

/// The MenuBarExtra dropdown content.
struct MenuContentView: View {
    @ObservedObject var appState: AppState

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        // MARK: Status section
        Group {
            Text(appState.isTracking ? "macsync — Tracking" : "macsync — Paused")
                .font(.headline)
            Text("Events today: \(appState.todayEventCount)")
            Text(syncStatusText)
            if let next = appState.nextScheduledSync {
                Text("Next auto-sync: \(next, formatter: Self.dateTimeFormatter)")
            }
        }

        Divider()

        // MARK: Actions
        Button(appState.isTracking ? "Pause Tracking" : "Resume Tracking") {
            appState.toggleTracking()
        }
        Button("Sync Now") {
            appState.syncNow()
        }
        Button("Open Data Folder") {
            appState.openDataFolder()
        }

        Divider()

        // MARK: Permissions
        permissionRow(
            label: "Accessibility (input counts)",
            granted: appState.accessibilityGranted,
            action: { appState.permissions.openAccessibilitySettings() }
        )
        permissionRow(
            label: "Screen Recording (window titles)",
            granted: appState.screenRecordingGranted,
            action: { appState.permissions.openScreenRecordingSettings() }
        )
        Button("Request / Review Permissions…") {
            appState.requestPermissions()
        }

        Divider()

        // MARK: Launch at Login
        Toggle("Launch at Login", isOn: Binding(
            get: { appState.launchAtLogin },
            set: { appState.toggleLaunchAtLogin($0) }
        ))
        .toggleStyle(.checkbox)

        if appState.launchAtLoginNeedsApproval {
            Button("Approval needed — open Login Items settings") {
                appState.openLoginItemsSettings()
            }
        }

        Divider()

        Button("Quit macsync") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        .onAppear {
            appState.refreshPermissionStatus()
            appState.refreshLaunchAtLoginStatus()
            appState.refreshStats()
            appState.nextScheduledSync = appState.scheduler.nextScheduledSync
        }
    }

    // MARK: - Helpers

    private var syncStatusText: String {
        guard let date = appState.lastSyncDate else { return "Last sync: never" }
        let formatted = Self.dateTimeFormatter.string(from: date)
        return appState.lastSyncSuccess
            ? "Last sync: \(formatted) — \(appState.lastSyncDetail)"
            : "Last sync FAILED (\(formatted)) — \(appState.lastSyncDetail)"
    }

    @ViewBuilder
    private func permissionRow(label: String, granted: Bool, action: @escaping () -> Void) -> some View {
        if granted {
            Text("✓ \(label)")
        } else {
            Button("✗ \(label) — grant…", action: action)
        }
    }
}
