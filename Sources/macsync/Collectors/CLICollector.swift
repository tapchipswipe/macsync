import Foundation

final class CLICollector {
    private var lastHistoryReadOffset: UInt64 = 0
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        // Read recent commands from ~/.zsh_history if available
        let historyPath = NSHomeDirectory() + "/.zsh_history"
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: historyPath)) else { return }
        defer { try? handle.close() }

        if lastHistoryReadOffset == 0 {
            // Seek near the end on first run (last 4KB)
            let fileLen = handle.seekToEndOfFile()
            lastHistoryReadOffset = fileLen > 4096 ? fileLen - 4096 : 0
        }

        try? handle.seek(toOffset: lastHistoryReadOffset)
        let data = handle.readDataToEndOfFile()
        lastHistoryReadOffset = (try? handle.offset()) ?? lastHistoryReadOffset

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else { return }
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for line in lines.suffix(10) {
            let cmd = parseCommandLine(line)
            guard !cmd.isEmpty else { continue }
            let isTest = cmd.contains("test") || cmd.contains("pytest") || cmd.contains("build") || cmd.contains("cargo")
            let payload = CLICommandPayload(
                observedAt: Date(),
                commandName: cmd,
                exitCode: 0,
                durationMs: 0,
                isBuildOrTest: isTest
            )
            DataStore.shared.append(TrackerEvent(ts: Date(), kind: .cliCommand, payload: .cliCommand(payload)))
        }
    }

    private func parseCommandLine(_ raw: String) -> String {
        // zsh history format: ": 1690000000:0;command args..."
        if let idx = raw.firstIndex(of: ";") {
            let after = raw[raw.index(after: idx)...]
            return String(after).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
