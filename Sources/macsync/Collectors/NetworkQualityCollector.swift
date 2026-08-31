import Foundation

final class NetworkQualityCollector {
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
        DispatchQueue.global(qos: .utility).async {
            let (ping, loss) = self.measurePing()
            let grade = self.calculateGrade(ping: ping, loss: loss)
            let payload = NetworkQualityPayload(
                observedAt: Date(),
                pingMs: ping,
                packetLossPercent: loss,
                qualityGrade: grade
            )
            DataStore.shared.append(TrackerEvent(ts: Date(), kind: .networkQuality, payload: .networkQuality(payload)))
        }
    }

    private func measurePing() -> (pingMs: Double, lossPct: Double) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/sbin/ping")
        p.arguments = ["-c", "3", "-t", "2", "1.1.1.1"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""

        var ping: Double = 25.0
        var loss: Double = 0.0

        if out.contains("packet loss") {
            let parts = out.components(separatedBy: "packet loss")
            if let before = parts.first?.split(separator: ",").last {
                let digits = before.filter { $0.isNumber || $0 == "." }
                if let num = Double(digits) { loss = num }
            }
        }
        if out.contains("avg") || out.contains("round-trip") {
            let lines = out.split(separator: "\n")
            if let last = lines.last, last.contains("/") {
                let slashParts = last.components(separatedBy: "/")
                if slashParts.count >= 5, let avg = Double(slashParts[4]) {
                    ping = avg
                }
            }
        }
        return (ping, loss)
    }

    private func calculateGrade(ping: Double, loss: Double) -> String {
        if loss > 5.0 { return "D" }
        if ping < 20.0 { return "A+" }
        if ping < 45.0 { return "A" }
        if ping < 85.0 { return "B" }
        if ping < 150.0 { return "C" }
        return "D"
    }
}
