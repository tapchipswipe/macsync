import Foundation

struct GitCommitNode: Identifiable, Codable {
    let id: UUID
    let repoName: String
    let branch: String
    let commitHash: String
    let message: String
    let author: String
    let timestamp: Date
    let minuteOfDay: Int

    init(id: UUID = UUID(), repoName: String, branch: String, commitHash: String, message: String, author: String, timestamp: Date) {
        self.id = id
        self.repoName = repoName
        self.branch = branch
        self.commitHash = commitHash
        self.message = message
        self.author = author
        self.timestamp = timestamp

        let cal = Calendar.current
        self.minuteOfDay = (cal.component(.hour, from: timestamp) * 60) + cal.component(.minute, from: timestamp)
    }

    var shortHash: String {
        String(commitHash.prefix(7))
    }
}

enum GitVelocityLinker {

    static func scanRecentCommits(since date: Date = Calendar.current.startOfDay(for: Date())) -> [GitCommitNode] {
        let home = NSHomeDirectory()
        let searchRoots = [
            "\(home)/Projects",
            "\(home)/Documents/Projects",
            "\(home)/repos",
            "\(home)/welift_sandbox"
        ]

        var nodes: [GitCommitNode] = []
        let fm = FileManager.default

        for root in searchRoots {
            guard fm.fileExists(atPath: root) else { continue }
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }

            for entry in entries {
                let repoDir = "\(root)/\(entry)"
                let gitDir = "\(repoDir)/.git"
                guard fm.fileExists(atPath: gitDir) else { continue }

                // Query git branch
                let branchProcess = Process()
                branchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                branchProcess.arguments = ["-C", repoDir, "rev-parse", "--abbrev-ref", "HEAD"]
                let branchPipe = Pipe()
                branchProcess.standardOutput = branchPipe
                try? branchProcess.run()
                branchProcess.waitUntilExit()

                let branchData = branchPipe.fileHandleForReading.readDataToEndOfFile()
                let branch = (String(data: branchData, encoding: .utf8) ?? "main").trimmingCharacters(in: .whitespacesAndNewlines)

                // Query git log
                let logProcess = Process()
                logProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                logProcess.arguments = [
                    "-C", repoDir, "log", "-n", "8",
                    "--pretty=format:%H|%an|%aI|%s"
                ]
                let logPipe = Pipe()
                logProcess.standardOutput = logPipe
                try? logProcess.run()
                logProcess.waitUntilExit()

                let logData = logPipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: logData, encoding: .utf8), !output.isEmpty else { continue }

                let lines = output.components(separatedBy: .newlines)
                let isoFormatter = ISO8601DateFormatter()

                for l in lines {
                    let parts = l.components(separatedBy: "|")
                    guard parts.count >= 4 else { continue }
                    let hash = parts[0]
                    let author = parts[1]
                    let dateStr = parts[2]
                    let msg = parts[3]

                    if let commitDate = isoFormatter.date(from: dateStr) {
                        nodes.append(GitCommitNode(
                            repoName: entry,
                            branch: branch.isEmpty ? "main" : branch,
                            commitHash: hash,
                            message: msg,
                            author: author,
                            timestamp: commitDate
                        ))
                    }
                }
            }
        }

        return nodes.sorted(by: { $0.timestamp > $1.timestamp })
    }
}
