import AppKit
import Foundation
import IOKit

/// Logs screen lock/unlock, system sleep/wake, and lid open/close.
/// No permissions required — pure notification observation.
final class SessionCollector {
    private let store = DataStore.shared
    private var observers: [NSObjectProtocol] = []
    private var lidTimer: Timer?
    private var lastLidClosed: Bool?

    func start() {
        stop()
        let dnc = DistributedNotificationCenter.default()
        let wnc = NSWorkspace.shared.notificationCenter

        observers.append(dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.log(.screenLocked)
        })
        observers.append(dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.log(.screenUnlocked)
        })
        observers.append(wnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.log(.systemSleep)
        })
        observers.append(wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.log(.systemWake)
            self?.checkLidChange()
        })

        // Lid state: seed, then poll on wake + a slow timer (there is no public
        // lid-change notification; IOPS power-source callbacks cover AC changes,
        // so we combine wake notification with a periodic check).
        lastLidClosed = Self.isLidClosed()
        let t = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkLidChange()
        }
        lidTimer = t
    }

    func stop() {
        lidTimer?.invalidate()
        lidTimer = nil
        for o in observers { DistributedNotificationCenter.default().removeObserver(o); NSWorkspace.shared.notificationCenter.removeObserver(o) }
        observers.removeAll()
    }

    private func checkLidChange() {
        let closed = Self.isLidClosed()
        guard closed != lastLidClosed else { return }
        lastLidClosed = closed
        log(closed ? .lidClosed : .lidOpened)
    }

    private func log(_ event: SessionEventPayload.SessionEventType) {
        let payload = SessionEventPayload(observedAt: Date(), event: event)
        store.append(TrackerEvent(ts: payload.observedAt, kind: .sessionEvent, payload: .sessionEvent(payload)))
    }

    /// True if a clamshell lid exists and is closed. Desktops report false.
    static func isLidClosed() -> Bool {
        let root = IORegistryEntryFromPath(kIOMainPortDefault, "IOPower:/")
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(root, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any],
              let clamshell = props["AppleClamshellState"] as? Bool else {
            return false
        }
        return clamshell
    }
}
