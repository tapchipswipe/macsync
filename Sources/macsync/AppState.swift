import AppKit
import Combine
import CoreLocation
import Foundation
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let permissions = PermissionsManager()
    let locationTracker = LocationTracker()
    private let appWindowTracker = AppWindowTracker()
    private let inputMetrics = InputMetricsTracker()
    private let browserTracker = BrowserTracker()
    private let hardwareMonitor = HardwareMonitor()
    private let idleTracker = IdleTracker()
    private let syncEngine = iCloudSync()
    private(set) lazy var scheduler = SyncScheduler(syncEngine: syncEngine)
    let updater = UpdateChecker.shared

    @Published var isTracking = false
    @Published var stats = TodayStats.empty
    @Published var todayEventCount = 0
    @Published var lastSyncDate: Date?
    @Published var lastSyncSuccess = false
    @Published var lastSyncDetail = "Never synced"
    @Published var nextScheduledSync: Date?
    @Published var missedDaysSynced = 0

    @Published var launchAtLogin = false
    @Published var launchAtLoginNeedsApproval = false
    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false
    /// True while macOS Secure Input is withholding keyDown events from the tap.
    @Published var secureInputSuppressed = false

    private var cancellables = Set<AnyCancellable>()
    private var locationPingTimer: Timer?
    private var aggregationTimer: Timer?

    private init() {
        DataStore.shared.onStatsChanged = { [weak self] in
            Task { @MainActor in self?.refreshStats() }
        }
        refreshStats()
        refreshLaunchAtLoginStatus()
        refreshPermissionStatus()
        refreshAggregation()    // seed stats immediately on init
        startAggregationTimer()
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching() {
        DataStore.shared.pruneBuffers(olderThan: 30)
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
        scheduler.onCatchUpSynced = { [weak self] count in
            Task { @MainActor in self?.missedDaysSynced = count }
        }
        updater.start()
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

    func toggleTracking() { isTracking ? stopTracking() : startTracking() }

    // MARK: - Stats / sync

    func refreshStats() {
        let store = DataStore.shared
        todayEventCount = store.todayEventCount
        lastSyncDate = store.lastSyncDate
        lastSyncSuccess = store.lastSyncSuccess
        lastSyncDetail = store.lastSyncDetail
    }

    func refreshAggregation() {
        enforceNightPause()
        let day = SyncFormat.dayString()
        let events = DataStore.shared.events(forDay: day)
        let archived = HistoryLoader.archivedEvents(daysBack: 7)
        stats = TodayAggregator.compute(events: events, archived: archived)
    }

    func syncNow() { scheduler.syncNow() }

    func openOnboarding() {
        OnboardingWindowController.shared.show(permissions: permissions)
    }

    // MARK: - Night pause (#17)

    private func enforceNightPause() {
        guard SyncOptions.nightPauseEnabled else {
            if !isTracking && pausedForNight { pausedForNight = false; startTracking() }
            return
        }
        if SyncOptions.isInNightPauseWindow() {
            if isTracking { stopTracking(); pausedForNight = true }
        } else if pausedForNight {
            pausedForNight = false
            startTracking()
        }
    }
    private var pausedForNight = false

    // MARK: - Health for menu-bar icon (#10)

    var healthIsBad: Bool {
        !accessibilityGranted || !screenRecordingGranted
            || (lastSyncDate != nil && !lastSyncSuccess)
    }

        private func startAggregationTimer() {
        aggregationTimer?.invalidate()
        // immediate first tick at 0.5s so the menu shows fresh stats on launch
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refreshAggregation(); self?.refreshPermissionStatus() }
        }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAggregation()
                self?.refreshPermissionStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        aggregationTimer = timer
    }

    private func startLocationPingTimer() {
        locationPingTimer?.invalidate()
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.locationTracker.ping() }
        }
        RunLoop.main.add(timer, forMode: .common)
        locationPingTimer = timer
    }

    // MARK: - Permissions

    func refreshPermissionStatus() {
        accessibilityGranted = permissions.isAccessibilityTrusted
        screenRecordingGranted = permissions.hasScreenRecording
        secureInputSuppressed = inputMetrics.secureInputSuppressed
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
            launchAtLogin = true; launchAtLoginNeedsApproval = false
        case .requiresApproval:
            launchAtLogin = true; launchAtLoginNeedsApproval = true
        case .notRegistered, .notFound:
            launchAtLogin = false; launchAtLoginNeedsApproval = false
        @unknown default:
            launchAtLogin = false; launchAtLoginNeedsApproval = false
        }
    }

    func toggleLaunchAtLogin(_ enable: Bool) {
        if enable {
            do { try SMAppService.mainApp.register() }
            catch { Log.app.error("SMAppService register failed: \(error.localizedDescription)") }
        } else {
            Task {
                do { try await SMAppService.mainApp.unregister() }
                catch { Log.app.error("SMAppService unregister failed: \(error.localizedDescription)") }
                await MainActor.run { self.refreshLaunchAtLoginStatus() }
            }
            return
        }
        refreshLaunchAtLoginStatus()
    }

    func openLoginItemsSettings() { SMAppService.openSystemSettingsLoginItems() }
    func openDataFolder() { NSWorkspace.shared.open(DataStore.shared.root) }
}
