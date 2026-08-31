import Foundation

final class ThermalCollector {
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        let state = ProcessInfo.processInfo.thermalState
        let level: String
        let throttled: Bool

        switch state {
        case .nominal:
            level = "nominal"
            throttled = false
        case .fair:
            level = "fair"
            throttled = false
        case .serious:
            level = "serious"
            throttled = true
        case .critical:
            level = "critical"
            throttled = true
        @unknown default:
            level = "nominal"
            throttled = false
        }

        let payload = ThermalStatePayload(
            observedAt: Date(),
            thermalLevel: level,
            cpuUsagePercent: 0.0,
            isThrottled: throttled
        )
        DataStore.shared.append(TrackerEvent(ts: Date(), kind: .thermalState, payload: .thermalState(payload)))
    }
}
