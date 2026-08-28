import CoreLocation
import Foundation

/// Periodic location pings via CLLocationManager.
/// Uses significant-change monitoring (very low power) plus hourly one-shot fixes.
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    private let store = DataStore.shared
    private let manager = CLLocationManager()
    private var started = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        guard !started else { return }
        started = true
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startMonitoringSignificantLocationChanges()
        case .denied, .restricted:
            logDenied(message: "Location permission \(status == .denied ? "denied" : "restricted")")
        @unknown default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        started = false
    }

    /// Request a fresh one-off ping (e.g., from an hourly timer in AppState).
    func ping() {
        guard started else { return }
        if manager.authorizationStatus == .authorized || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let payload = LocationPingPayload(
            observedAt: Date(),
            latitude: latest.coordinate.latitude,
            longitude: latest.coordinate.longitude,
            accuracyMeters: latest.horizontalAccuracy,
            denied: false,
            errorMessage: nil
        )
        store.append(TrackerEvent(ts: Date(), kind: .locationPing, payload: .locationPing(payload)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let payload = LocationPingPayload(
            observedAt: Date(), latitude: nil, longitude: nil, accuracyMeters: nil,
            denied: false, errorMessage: error.localizedDescription
        )
        store.append(TrackerEvent(ts: Date(), kind: .locationPing, payload: .locationPing(payload)))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorized || status == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startMonitoringSignificantLocationChanges()
        } else if status == .denied || status == .restricted {
            logDenied(message: "Location permission revoked")
        }
    }

    private func logDenied(message: String) {
        let payload = LocationPingPayload(
            observedAt: Date(), latitude: nil, longitude: nil, accuracyMeters: nil,
            denied: true, errorMessage: message
        )
        store.append(TrackerEvent(ts: Date(), kind: .locationPing, payload: .locationPing(payload)))
    }
}
