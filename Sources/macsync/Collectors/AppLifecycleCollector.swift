import AppKit
import Foundation

/// Logs app launch / termination events via NSWorkspace notifications.
/// Complements appFocus tracking with app churn / launch frequency stats.
final class AppLifecycleCollector {
    private let store = DataStore.shared
    private var observers: [NSObjectProtocol] = []

    func start() {
        stop()
        let wnc = NSWorkspace.shared.notificationCenter
        observers.append(wnc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.log(app, event: .launched)
        })
        observers.append(wnc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.log(app, event: .terminated)
        })
    }

    func stop() {
        for o in observers { NSWorkspace.shared.notificationCenter.removeObserver(o) }
        observers.removeAll()
    }

    private func log(_ app: NSRunningApplication, event: AppLifecyclePayload.LifecycleEvent) {
        guard let name = app.localizedName else { return }
        let now = Date()
        let payload = AppLifecyclePayload(observedAt: now, appName: name,
                                          bundleID: app.bundleIdentifier, event: event)
        store.append(TrackerEvent(ts: now, kind: .appLifecycle, payload: .appLifecycle(payload)))
    }
}