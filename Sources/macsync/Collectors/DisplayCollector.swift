import Foundation
import AppKit

final class DisplayCollector {
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        DispatchQueue.main.async {
            let screens = NSScreen.screens
            let count = screens.count
            let hasExternal = count > 1
            let primarySize = screens.first?.frame.size ?? CGSize.zero
            let resolution = "\(Int(primarySize.width))x\(Int(primarySize.height))"

            let payload = DisplayTopologyPayload(
                observedAt: Date(),
                screenCount: count,
                hasExternalDisplay: hasExternal,
                primaryResolution: resolution
            )
            DataStore.shared.append(TrackerEvent(ts: Date(), kind: .displayTopology, payload: .displayTopology(payload)))
        }
    }
}
