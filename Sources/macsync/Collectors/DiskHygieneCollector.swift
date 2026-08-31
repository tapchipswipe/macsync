import Foundation

final class DiskHygieneCollector {
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        DispatchQueue.global(qos: .background).async {
            let (dlSizeGB, staleCount) = self.scanDownloadsFolder()
            let freeGB = self.getFreeDiskSpaceGB()
            let payload = DiskHygienePayload(
                observedAt: Date(),
                downloadsSizeGB: dlSizeGB,
                staleInstallerCount: staleCount,
                freeDiskSpaceGB: freeGB
            )
            DataStore.shared.append(TrackerEvent(ts: Date(), kind: .diskHygiene, payload: .diskHygiene(payload)))
        }
    }

    private func scanDownloadsFolder() -> (sizeGB: Double, staleInstallers: Int) {
        let downloads = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        guard let files = try? FileManager.default.contentsOfDirectory(at: downloads, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles) else {
            return (0.0, 0)
        }

        var totalBytes: Int64 = 0
        var staleCount = 0
        let twoWeeksAgo = Date().addingTimeInterval(-86400 * 14)

        for file in files {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            totalBytes += size

            let ext = file.pathExtension.lowercased()
            if (ext == "dmg" || ext == "pkg" || ext == "iso") {
                if let mod = values?.contentModificationDate, mod < twoWeeksAgo {
                    staleCount += 1
                }
            }
        }

        let sizeGB = Double(totalBytes) / 1_073_741_824.0
        return (sizeGB, staleCount)
    }

    private func getFreeDiskSpaceGB() -> Double {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let avail = values.volumeAvailableCapacityForImportantUsage {
            return Double(avail) / 1_073_741_824.0
        }
        return 50.0
    }
}
