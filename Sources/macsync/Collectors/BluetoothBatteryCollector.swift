import Foundation

final class BluetoothBatteryCollector {
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 180.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        DispatchQueue.global(qos: .utility).async {
            let devices = self.readBluetoothBatteries()
            let payload = BluetoothBatteryPayload(
                observedAt: Date(),
                devices: devices
            )
            DataStore.shared.append(TrackerEvent(ts: Date(), kind: .bluetoothBattery, payload: .bluetoothBattery(payload)))
        }
    }

    private func readBluetoothBatteries() -> [BluetoothDeviceBattery] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        var devices: [BluetoothDeviceBattery] = []
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let root = json["SPBluetoothDataType"] as? [[String: Any]] else {
            return devices
        }

        for entry in root {
            if let connected = entry["device_connected"] as? [[String: Any]] {
                for item in connected {
                    for (name, val) in item {
                        if let details = val as? [String: Any],
                           let batteryStr = details["device_batteryLevelMain"] as? String,
                           let pct = Int(batteryStr.replacingOccurrences(of: "%", with: "")) {
                            devices.append(BluetoothDeviceBattery(name: name, batteryPercent: pct))
                        }
                    }
                }
            }
        }
        return devices
    }
}
