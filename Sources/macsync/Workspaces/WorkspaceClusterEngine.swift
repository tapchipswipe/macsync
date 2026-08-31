import Foundation

struct WorkspaceCluster: Identifiable, Codable {
    var id: String { name.lowercased() }
    let name: String
    let icon: String
    let colorHex: String
    let wifiSSIDs: [String]
    let totalActiveMinutes: Int
    let totalSpend: Decimal
    let keystrokes: Int
    let averageCPM: Double
}

enum WorkspaceClusterEngine {

    /// User-defined or auto-discovered workspace mappings.
    private static let knownNetworks: [String: (name: String, icon: String, color: String)] = [
        "home": ("Home Studio", "house.fill", "#5B8CFF"),
        "office": ("Office HQ", "building.2.fill", "#63E6BE"),
        "campus": ("Campus Studio", "graduationcap.fill", "#A78BFA"),
        "guest": ("Guest / Coffee Shop", "cup.and.saucer.fill", "#F59E0B"),
        "starbucks": ("Coffee Shop", "cup.and.saucer.fill", "#F59E0B")
    ]

    /// Clusters events by location / Wi-Fi network.
    static func analyze(events: [TrackerEvent]) -> [WorkspaceCluster] {
        var networkUsage: [String: (mins: Int, keys: Int, spend: Decimal)] = [:]

        var currentSSID: String = "Primary Workspace"
        for e in events {
            if case .networkContext(let net) = e.payload {
                if let ssid = net.ssid, !ssid.isEmpty {
                    currentSSID = ssid
                    if networkUsage[currentSSID] == nil {
                        networkUsage[currentSSID] = (0, 0, 0)
                    }
                }
            } else if case .appFocus(let a) = e.payload {
                var stats = networkUsage[currentSSID] ?? (0, 0, 0)
                stats.mins += Int(a.durationSeconds / 60)
                networkUsage[currentSSID] = stats
            } else if case .inputMetrics(let inp) = e.payload {
                var stats = networkUsage[currentSSID] ?? (0, 0, 0)
                stats.keys += inp.keystrokeCount
                networkUsage[currentSSID] = stats
            } else if case .receipt(let r) = e.payload {
                var stats = networkUsage[currentSSID] ?? (0, 0, 0)
                stats.spend += r.amount
                networkUsage[currentSSID] = stats
            }
        }

        var clusters: [WorkspaceCluster] = []
        for (ssid, stats) in networkUsage {
            let lower = ssid.lowercased()
            var name = ssid
            var icon = "network"
            var color = "#5B8CFF"

            for (key, match) in knownNetworks {
                if lower.contains(key) {
                    name = match.name
                    icon = match.icon
                    color = match.color
                    break
                }
            }

            let cpm = stats.mins > 0 ? Double(stats.keys) / Double(stats.mins) : 0
            clusters.append(WorkspaceCluster(
                name: name,
                icon: icon,
                colorHex: color,
                wifiSSIDs: [ssid],
                totalActiveMinutes: stats.mins,
                totalSpend: stats.spend,
                keystrokes: stats.keys,
                averageCPM: cpm
            ))
        }

        clusters.sort { $0.totalActiveMinutes > $1.totalActiveMinutes }
        return clusters
    }
}
