import Foundation

public struct GuardianSweepRecord: Codable {
    public let timestamp: Date
    public let reason: String
    public let bytesFreed: Int64
    public let freeSpaceAfterGB: Double

    public var bytesFreedFormatted: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }
}

public final class AutoEvictionGuardian {
    public static let shared = AutoEvictionGuardian()

    private var timer: Timer?
    private let minimumFreeThresholdGB: Double = 15.0 // Trigger if < 15GB free
    private(set) var lastRecord: GuardianSweepRecord? = nil

    public func start() {
        timer?.invalidate()
        // Check storage health every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 900.0, repeats: true) { [weak self] _ in
            self?.checkAndGuard()
        }
        checkAndGuard()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func checkAndGuard() {
        DispatchQueue.global(qos: .background).async {
            let snapshot = iCloudStorageOptimizer.scanStorage()
            let freeGB = Double(snapshot.freeDiskBytes) / 1_073_741_824.0

            // If free space is critical or above 90% capacity, run autonomous guardian sweep
            if freeGB < self.minimumFreeThresholdGB || snapshot.diskUsagePercentage >= 90.0 {
                let freed = self.performAutonomousSweep(reason: "Free disk (\(String(format: "%.1f", freeGB)) GB) below \(Int(self.minimumFreeThresholdGB)) GB threshold")
                let updatedSnapshot = iCloudStorageOptimizer.scanStorage()
                let updatedFreeGB = Double(updatedSnapshot.freeDiskBytes) / 1_073_741_824.0

                let rec = GuardianSweepRecord(
                    timestamp: Date(),
                    reason: "Automated storage defense triggered (< 15GB)",
                    bytesFreed: freed,
                    freeSpaceAfterGB: updatedFreeGB
                )
                self.lastRecord = rec
            }
        }
    }

    /// Performs safe autonomous optimization without user intervention.
    public func performAutonomousSweep(reason: String) -> Int64 {
        var totalFreed: Int64 = 0

        // 1. Triage downloads
        let (_, dlBytes) = DownloadTriageEngine.executeTriage()
        totalFreed += dlBytes

        // 2. Evict unpinned iCloud items
        let snapshot = iCloudStorageOptimizer.scanStorage()
        for candidate in snapshot.candidates {
            if candidate.category == .iCloudEvictable && !FolderPinningEngine.isProtectedFromEviction(path: candidate.path) {
                if iCloudStorageOptimizer.evictItem(atPath: candidate.path) {
                    totalFreed += candidate.sizeBytes
                }
            }
        }

        // 3. Trim inactive developer project bloat (node_modules, build caches)
        let devReclaimed = DeveloperProjectTrimmer.trimAllCandidates()
        totalFreed += devReclaimed

        // 4. Purge disposable system caches
        let cacheReclaimed = iCloudStorageOptimizer.purgeUserCaches()
        totalFreed += cacheReclaimed

        return totalFreed
    }
}
