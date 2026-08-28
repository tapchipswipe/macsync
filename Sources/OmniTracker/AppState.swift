import AppKit
import Combine
import Foundation
import ServiceManagement

/// Central application state, exposed to the MenuBarExtra UI.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Collectors / services

    let permissions = PermissionsManager()
    let locationTracker = LocationTracker()
    private let appWindowTracker = AppWindowTracker()
    private let inputMetrics = InputMetricsTracker()
    private let browserTracker = BrowserTracker()
    private let hardwareMonitor = HardwareMonitor()
    private let idleTracker = IdleTracker()
    private let syncEngine = iCloudSync()
    private(set) lazy var scheduler = SyncScheduler(syncEngine: syncEngine)

    // MARK: - Published state

    @Published var isTracking = false
    @Published var todayEventCount = 0
    @Published var lastSyncDate: Date?
    @Published var lastSyncSuccess = false
    @Published var lastSyncDetail = "Never synced"
    @Published var nextScheduledSync: Date?

    // Launch at Login
    @Published var launchAtLogin = false
    @Published var launchAtLoginNeedsApproval = false

    // Permission status (refreshed when menu opens)
    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false

    private var cancellables = Set<AnyCancellable>()
    private var locationPingTimer: Timer?

    private init() {
        DataStore.shared.onStatsChanged = { [weak self] in
            Task { @MainActor in self?.refreshStats() }
        }
        refreshStats()
        refreshLaunchAtLoginStatus()
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching() {
        permissions.runOnboardingIfNeeded(locationTracker: locationTracker)
        startTracking()
        scheduler.start()
        nextScheduledSync = scheduler.nextScheduledSync
        scheduler.onSyncFired = { [weak self] in
            Task { @MainActor in
                self?.nextScheduledSync = self?.scheduler.nextScheduledSync
                self?.refreshStats()
            }
        }
        startLocationPingTimer()
    }

    func applicationWillTerminate() {
        stopTracking()
        scheduler.stop()
    }

    // MARK: - Tracking control

    func startTracking() {
        guard !isTracking else { return }
        appWindowTracker.start()
        inputMetrics.start()
        browserTracker.start()
        hardwareMonitor.start()
        idleTracker.start()
        locationTracker.start()
        isTracking = true
    }

    func stopTracking() {
        guard isTracking else { return }
        appWindowTracker.stop()
        inputMetrics.stop()
        browserTracker.stop()
        hardwareMonitor.stop()
        idleTracker.stop()
        isTracking = false
    }

    func toggleTracking() {
        isTracking ? stopTracking() : startTracking()
    }

    // MARK: - Stats / sync

    func refreshStats() {
        let store = DataStore.shared
        todayEventCount = store.todayEventCount
        lastSyncDate = store.lastSyncDate
        lastSyncSuccess = store.lastSyncSuccess
        lastSyncDetail = store.lastSyncDetail
    }

    func syncNow() {
        scheduler.syncNow()
    }

    private func startLocationPingTimer() {
        locationPingTimer?.invalidate()
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.locationTracker.ping() }
        }
        RunLoop.main.add(timer, forMode: .common)
        locationPingTimer = timer
    }

    // MARK: - Permissions UI support

    func refreshPermissionStatus() {
        accessibilityGranted = permissions.isAccessibilityTrusted
        screenRecordingGranted = permissions.hasScreenRecording
    }

    func requestPermissions() {
        permissions.requestAccessibility()
        permissions.requestScreenRecording()
        permissions.requestAutomationConsent()
        refreshPermissionStatus()
    }

    // MARK: - Launch at Login (SMAppService)

    func refreshLaunchAtLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLogin = true
            launchAtLoginNeedsApproval = false
        case .requiresApproval:
            launchAtLogin = true
            launchAtLoginNeedsApproval = true
        case .notRegistered, .notFound:
            launchAtLogin = false
            launchAtLoginNeedsApproval = false
        @unknown default:
            launchAtLogin = false
            launchAtLoginNeedsApproval = false
        }
    }

    func toggleLaunchAtLogin(_ enable: Bool) {
        if enable {
            do {
                try SMAppService.mainApp.register()
            } catch {
                NSLog("OmniTracker: SMAppService register failed: \(error.localizedDescription)")
            }
        } else {
            // unregister() is async throws on the modern SDK.
            Task {
                do {
                    try await SMAppService.mainApp.unregister()
                } catch {
                    NSLog("OmniTracker: SMAppService unregister failed: \(error.localizedDescription)")
                }
                await MainActor.run { self.refreshLaunchAtLoginStatus() }
            }
            return
        }
        refreshLaunchAtLoginStatus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Misc actions

    func openDataFolder() {
        NSWorkspace.shared.open(DataStore.shared.root)
    }
}
