import Foundation

final class GitCollector {
    private var timer: Timer?
    private let repoPaths: [String] = [
        "/Users/lucasdespot/macsync",
        "/Users/lucasdespot/paper_trading_bot"
    ]

    func start() {
        timer?.invalidate()
        // Poll git status periodically every 60s
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        for path in repoPaths {
            guard FileManager.default.fileExists(atPath: "\(path)/.git") else { continue }
            let repoName = (path as NSString).lastPathComponent
            let branch = runGit(args: ["branch", "--show-current"], at: path).trimmingCharacters(in: .whitespacesAndNewlines)
            let diffStat = runGit(args: ["diff", "--shortstat"], at: path)
            let diffLines = parseDiffLines(diffStat)
            let commitCount = countCommitsToday(at: path)

            let payload = GitVelocityPayload(
                observedAt: Date(),
                repoName: repoName,
                branch: branch.isEmpty ? "main" : branch,
                uncommittedDiffLines: diffLines,
                commitsToday: commitCount
            )
            DataStore.shared.append(TrackerEvent(ts: Date(), kind: .gitVelocity, payload: .gitVelocity(payload)))
        }
    }

    private func runGit(args: [String], at cwd: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", cwd] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseDiffLines(_ text: String) -> Int {
        // e.g. " 3 files changed, 24 insertions(+), 12 deletions(-)"
        var total = 0
        let parts = text.components(separatedBy: ",")
        for p in parts {
            if p.contains("insertion") || p.contains("deletion") {
                let digits = p.filter { $0.isNumber }
                if let num = Int(digits) { total += num }
            }
        }
        return total
    }

    private func countCommitsToday(at cwd: String) -> Int {
        let output = runGit(args: ["log", "--since=midnight", "--oneline"], at: cwd)
        let lines = output.split(separator: "\n").filter { !$0.isEmpty }
        return lines.count
    }
}
