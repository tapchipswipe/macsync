import CoreWLAN
import CryptoKit
import Foundation
import Network

/// Wi-Fi context (SSID, hashed BSSID, signal) + VPN detection.
/// BSSID is SHA-256 hashed before storage so a network is recognizable
/// day-to-day but not mappable to a physical access point.
final class NetworkContextCollector {
    private let store = DataStore.shared
    private var timer: Timer?

    private let pollInterval: TimeInterval = 120   // every 2 minutes

    func start() {
        stop()
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

    private func poll() {
        // CWWiFiClient needs to be accessed from a serial context; it returns
        // nil interfaces when Wi-Fi is off or when denied.
        var ssid: String?
        var bssidHash: String?
        var rssi: Int?

        if let interface = CWWiFiClient.shared().interface() {
            ssid = interface.ssid()
            if let bssid = interface.bssid() {
                bssidHash = Self.hash(bssid)
            }
            rssi = interface.rssiValue()
        }

        let payload = NetworkContextPayload(observedAt: Date(),
                                            ssid: ssid,
                                            bssidHash: bssidHash,
                                            rssi: rssi,
                                            onVPN: Self.isVPNConnected())
        store.append(TrackerEvent(ts: payload.observedAt, kind: .networkContext, payload: .networkContext(payload)))
    }

    private static func hash(_ bssid: String) -> String {
        // BSSID is "00:11:22:33:44:55"; hash the hex string.
        let data = Data(bssid.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Detect VPN by scanning for utun/tap/tun interfaces beyond lo0/en.
    static func isVPNConnected() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }

        var found = false
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let name = String(cString: ptr.pointee.ifa_name)
            if name.hasPrefix("utun") || name.hasPrefix("tap") || name.hasPrefix("tun") {
                found = true
                break
            }
        }
        return found
    }
}