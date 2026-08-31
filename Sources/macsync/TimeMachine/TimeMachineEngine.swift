import Foundation

struct TimeMachineFrame: Identifiable {
    var id: Int { minuteOfDay }
    let minuteOfDay: Int
    let timeString: String
    let activeApp: String?
    let windowTitle: String?
    let keystrokes: Int
    let inCall: Bool
    let musicTitle: String?
    let wifiSSID: String?
    let purchaseAmount: Decimal?
    let purchaseMerchant: String?
    let intensity: Double
}

enum TimeMachineEngine {

    /// Discretizes events into 5-minute frames across 24 hours (288 frames).
    static func buildTimeline(events: [TrackerEvent], date: Date = Date()) -> [TimeMachineFrame] {
        let cal = Calendar.current
        var frameMap: [Int: (app: String?, title: String?, keys: Int, inCall: Bool, music: String?, wifi: String?, spend: Decimal?, merchant: String?)] = [:]

        // Prepopulate 288 five-minute frames
        for frameIndex in 0..<288 {
            let minute = frameIndex * 5
            frameMap[minute] = (nil, nil, 0, false, nil, nil, nil, nil)
        }

        var currentSSID: String? = nil
        var currentMusic: String? = nil
        var inCallState = false

        for e in events {
            let minute = (cal.component(.hour, from: e.ts) * 60) + cal.component(.minute, from: e.ts)
            let frameMinute = (minute / 5) * 5

            var frame = frameMap[frameMinute] ?? (nil, nil, 0, false, nil, nil, nil, nil)

            switch e.payload {
            case .windowFocus(let w):
                frame.app = w.appName
                frame.title = w.windowTitle
            case .appFocus(let a):
                if frame.app == nil { frame.app = a.appName }
            case .inputMetrics(let inp):
                frame.keys += inp.keystrokeCount
            case .cameraMicState(let cam):
                if cam.cameraActive || cam.microphoneActive { inCallState = true }
                else { inCallState = false }
                frame.inCall = inCallState
            case .nowPlaying(let now):
                if now.isPlaying { currentMusic = now.title }
                else { currentMusic = nil }
                frame.music = currentMusic
            case .networkContext(let net):
                if let ssid = net.ssid { currentSSID = ssid }
                frame.wifi = currentSSID
            case .receipt(let r):
                frame.spend = (frame.spend ?? 0) + r.amount
                frame.merchant = r.merchant
            default:
                break
            }

            frameMap[frameMinute] = frame
        }

        var result: [TimeMachineFrame] = []
        for frameIndex in 0..<288 {
            let minute = frameIndex * 5
            let data = frameMap[minute] ?? (nil, nil, 0, false, nil, nil, nil, nil)

            let h = minute / 60
            let m = minute % 60
            let timeStr = String(format: "%02d:%02d", h, m)

            var intensity = 0.0
            if data.keys > 0 { intensity += min(1.0, Double(data.keys) / 100.0) * 0.7 }
            if data.app != nil { intensity += 0.3 }
            if data.inCall { intensity += 0.4 }

            result.append(TimeMachineFrame(
                minuteOfDay: minute,
                timeString: timeStr,
                activeApp: data.app,
                windowTitle: data.title,
                keystrokes: data.keys,
                inCall: data.inCall,
                musicTitle: data.music,
                wifiSSID: data.wifi,
                purchaseAmount: data.spend,
                purchaseMerchant: data.merchant,
                intensity: min(1.0, intensity)
            ))
        }

        return result
    }
}
