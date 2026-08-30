import Foundation
import Intents

/// Polls macOS Focus (Do Not Disturb / Work / Personal…) state via
/// INFocusStatusCenter. Requires a one-time Focus authorization prompt;
/// degrades gracefully (logs authorized=false) if denied.
final class FocusModeCollector {
    private let store = DataStore.shared
    private var timer: Timer?
    private var lastState: Bool?

    private let pollInterval: TimeInterval = 60

    func start() {
        stop()
        requestAuthorizationIfNeeded()
        let t = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        t.fire()
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func requestAuthorizationIfNeeded() {
        let center = INFocusStatusCenter.default
        guard center.authorizationStatus == .notDetermined else { return }
        center.requestAuthorization { _ in }
    }

    private func poll() {
        let center = INFocusStatusCenter.default
        let status = center.authorizationStatus
        let authorized = (status == .authorized)
        let focused = authorized ? (center.focusStatus.isFocused ?? false) : false

        // Log on state change and every 15 polls (heartbeat) so daily archives
        // always contain the current focus context.
        if focused != lastState || Int(Date().timeIntervalSince1970) % (15 * 60) < Int(pollInterval) {
            lastState = focused
            let payload = FocusModePayload(observedAt: Date(), focusActive: focused, authorized: authorized)
            store.append(TrackerEvent(ts: payload.observedAt, kind: .focusModeState, payload: .focusModeState(payload)))
        }
    }
}
