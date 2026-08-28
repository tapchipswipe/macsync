import AppKit
import Foundation

/// Checks GitHub Releases for a newer version (#built-in updater).
/// Hits the public API once at launch and then once per day.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    static let repo = "tapchipswipe/macsync"

    enum State: Equatable {
        case idle, checking, upToDate, available, failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var latestVersion: String?
    @Published private(set) var downloadPage: URL?

    private var timer: Timer?
    private var lastCheck: Date?

    var isUpdateAvailable: Bool { state == .available }

    func start() {
        checkNow()
        scheduleDaily()
    }

    func checkNow() {
        guard state != .checking else { return }
        state = .checking
        Task { await check() }
    }

    private func scheduleDaily() {
        timer?.invalidate()
        let t = Timer(timeInterval: 86_400, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkNow() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func check() async {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
            state = .failed; return
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Release: Decodable { let tagName: String; let htmlUrl: String
                enum CodingKeys: String, CodingKey { case tagName = "tag_name", htmlUrl = "html_url" } }
            let release = try JSONDecoder().decode(Release.self, from: data)
            latestVersion = release.tagName
            downloadPage = URL(string: release.htmlUrl)
            if Self.isNewer(release.tagName, than: Self.currentVersion()) {
                state = .available
                Log.app.info("Update available: \(release.tagName)")
            } else {
                state = .upToDate
            }
        } catch {
            Log.app.error("Update check failed: \(error.localizedDescription)")
            state = .failed
        }
        lastCheck = Date()
    }

    func openDownloadPage() {
        if let url = downloadPage ?? URL(string: "https://github.com/\(Self.repo)/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Version helpers

    static func currentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Compares "v1.2.3"-style tags numerically.
    nonisolated static func isNewer(_ latest: String, than current: String) -> Bool {
        let l = numeric(latest)
        let c = numeric(current)
        for i in 0..<max(l.count, c.count) {
            let a = i < l.count ? l[i] : 0
            let b = i < c.count ? c[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    nonisolated private static func numeric(_ tag: String) -> [Int] {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".").map { Int($0) ?? 0 }
    }
}
