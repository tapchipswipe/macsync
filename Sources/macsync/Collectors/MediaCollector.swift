import AppKit
import Foundation

/// Reads system Now Playing metadata via the private MediaRemote framework
/// (read-only — same technique as nowplaying-cli). Degrades silently to
/// no data if the framework or symbols are unavailable.
final class MediaCollector {
    private let store = DataStore.shared
    private var timer: Timer?
    private var lastTrackKey: String?

    private let pollInterval: TimeInterval = 30

    // MediaRemote dynamic bindings
    private typealias GetNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
    private typealias GetNowPlayingAppIsPlayingFunc = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private var getNowPlayingInfo: GetNowPlayingInfoFunc?
    private var getIsPlaying: GetNowPlayingAppIsPlayingFunc?

    init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else { return }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfo = unsafeBitCast(sym, to: GetNowPlayingInfoFunc.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            getIsPlaying = unsafeBitCast(sym, to: GetNowPlayingAppIsPlayingFunc.self)
        }
    }

    func start() {
        stop()
        guard getNowPlayingInfo != nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        t.fire()
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard let getNowPlayingInfo else { return }
        getNowPlayingInfo(DispatchQueue.global(qos: .utility)) { [weak self] info in
            guard let self else { return }
            self.handleInfo(info)
        }
    }

    private func handleInfo(_ info: [String: Any]?) {
        guard let info, !info.isEmpty else {
            // Nothing playing: log a stop only if we previously saw a track.
            if lastTrackKey != nil {
                lastTrackKey = nil
                append(app: nil, title: nil, artist: nil, playing: false)
            }
            return
        }

        let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
        let appBundle = info["kMRMediaRemoteNowPlayingInfoClientBundleIdentifier"] as? String
        let appName = appBundle.flatMap(Self.appName(forBundleID:)) ?? appBundle

        let key = "\(appBundle ?? "")|\(title ?? "")|\(artist ?? "")"
        guard key != lastTrackKey else { return }   // unchanged track — skip
        lastTrackKey = key

        append(app: appName, title: title, artist: artist, playing: true)
    }

    private func append(app: String?, title: String?, artist: String?, playing: Bool) {
        let payload = NowPlayingPayload(
            observedAt: Date(),
            appName: app,
            title: title,
            artist: artist,
            isPlaying: playing
        )
        store.append(TrackerEvent(ts: payload.observedAt, kind: .nowPlaying, payload: .nowPlaying(payload)))
    }

    private static func appName(forBundleID bundleID: String) -> String? {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?
            .localizedName
    }
}
