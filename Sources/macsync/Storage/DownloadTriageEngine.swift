import Foundation

public struct TriageRuleItem: Identifiable, Codable {
    public let id: UUID
    public let filename: String
    public let sourcePath: String
    public let targetCloudPath: String
    public let targetFolderName: String
    public let sizeBytes: Int64

    public init(id: UUID = UUID(), filename: String, sourcePath: String, targetCloudPath: String, targetFolderName: String, sizeBytes: Int64) {
        self.id = id
        self.filename = filename
        self.sourcePath = sourcePath
        self.targetCloudPath = targetCloudPath
        self.targetFolderName = targetFolderName
        self.sizeBytes = sizeBytes
    }

    public var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public enum DownloadTriageEngine {

    public static func planTriage() -> [TriageRuleItem] {
        let home = NSHomeDirectory()
        let dlPath = "\(home)/Downloads"
        let cloudDocs = "\(home)/Library/Mobile Documents/com~apple~CloudDocs"
        let fm = FileManager.default

        guard fm.fileExists(atPath: dlPath),
              let files = try? fm.contentsOfDirectory(atPath: dlPath) else {
            return []
        }

        var plan: [TriageRuleItem] = []
        let twoDaysAgo = Date().addingTimeInterval(-86400 * 2)

        for file in files {
            if file.hasPrefix(".") { continue }
            let fullSource = "\(dlPath)/\(file)"

            guard let attrs = try? fm.attributesOfItem(atPath: fullSource),
                  let modDate = attrs[.modificationDate] as? Date,
                  let size = attrs[.size] as? Int64,
                  size > 1_000_000 else {
                continue
            }

            let ext = (file as NSString).pathExtension.lowercased()

            let targetFolder: String
            let targetSubdir: String

            if ["dmg", "pkg", "iso", "tar", "zip"].contains(ext) && modDate < twoDaysAgo {
                targetFolder = "Archive/Installers"
                targetSubdir = "\(cloudDocs)/Archive/Installers"
            } else if ["mov", "mp4", "wav", "m4a", "avi"].contains(ext) {
                targetFolder = "Media/Downloads"
                targetSubdir = "\(cloudDocs)/Media/Downloads"
            } else if ["csv", "pdf", "xlsx", "docx"].contains(ext) && modDate < twoDaysAgo {
                targetFolder = "Downloads_Evicted"
                targetSubdir = "\(cloudDocs)/Downloads_Evicted"
            } else {
                continue
            }

            plan.append(TriageRuleItem(
                filename: file,
                sourcePath: fullSource,
                targetCloudPath: "\(targetSubdir)/\(file)",
                targetFolderName: targetFolder,
                sizeBytes: size
            ))
        }

        return plan.sorted(by: { $0.sizeBytes > $1.sizeBytes })
    }

    public static func executeTriage() -> (itemsMoved: Int, bytesReclaimed: Int64) {
        let plan = planTriage()
        let fm = FileManager.default
        var moved = 0
        var bytes: Int64 = 0

        for item in plan {
            let targetDir = (item.targetCloudPath as NSString).deletingLastPathComponent
            try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

            do {
                if fm.fileExists(atPath: item.targetCloudPath) {
                    try fm.removeItem(atPath: item.targetCloudPath)
                }
                try fm.moveItem(atPath: item.sourcePath, toPath: item.targetCloudPath)
                _ = iCloudStorageOptimizer.evictItem(atPath: item.targetCloudPath)
                moved += 1
                bytes += item.sizeBytes
            } catch {
                continue
            }
        }

        return (moved, bytes)
    }
}
