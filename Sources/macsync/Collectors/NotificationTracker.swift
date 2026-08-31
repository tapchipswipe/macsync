import Foundation

final class NotificationTracker {
    private var observer: Any?

    func start() {
        // Observe distributed system notifications
        observer = DistributedNotificationCenter.default().addObserver(
            forName: nil,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            self?.handleNotification(notif)
        }
    }

    func stop() {
        if let obs = observer {
            DistributedNotificationCenter.default().removeObserver(obs)
            observer = nil
        }
    }

    private func handleNotification(_ notif: Notification) {
        let name = notif.name.rawValue
        if name.contains("Notification") || name.contains("Banner") || name.contains("Message") {
            let app = notif.object as? String ?? "System"
            let payload = NotificationEventPayload(
                observedAt: Date(),
                sourceApp: app
            )
            DataStore.shared.append(TrackerEvent(ts: Date(), kind: .notificationEvent, payload: .notificationEvent(payload)))
        }
    }
}
