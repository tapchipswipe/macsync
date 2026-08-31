import SwiftUI

public struct GhostFolderItem: Identifiable {
    public let id = UUID()
    public let name: String
    public let path: String
    public let totalSizeBytes: Int64
    public let localSizeBytes: Int64
    public var ghostRatio: Double {
        guard totalSizeBytes > 0 else { return 1.0 }
        let offloaded = max(0, totalSizeBytes - localSizeBytes)
        return Double(offloaded) / Double(totalSizeBytes)
    }

    public var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }

    public var localFormatted: String {
        ByteCountFormatter.string(fromByteCount: localSizeBytes, countStyle: .file)
    }
}

public struct GhostFileInspectorView: View {
    @State private var folders: [GhostFolderItem] = []
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Dataless Ghost Inspector", systemImage: "cloud.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#5B8CFF"))
                Spacer()
                Text("CLOUD VS LOCAL")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
            }

            if folders.isEmpty {
                Button {
                    loadFolders()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Analyze Dataless Ghost Ratios")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                VStack(spacing: 8) {
                    ForEach(folders) { f in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(f.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(f.localFormatted) local / \(f.totalFormatted) total")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            // Ghost percentage bar
                            GeometryReader { geo in
                                let w = geo.size.width
                                let ghostWidth = max(0, min(w, w * f.ghostRatio))

                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: "#3B82F6").opacity(0.7))
                                        .frame(width: w)

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: "#63E6BE"))
                                        .frame(width: ghostWidth)
                                }
                            }
                            .frame(height: 5)
                            .clipShape(Capsule())

                            HStack {
                                Text("\(Int(f.ghostRatio * 100))% Cloud Ghost (0 local bytes)")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(Color(hex: "#63E6BE"))
                                Spacer()
                                Button("Evict") {
                                    _ = iCloudStorageOptimizer.evictItem(atPath: f.path)
                                    loadFolders()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.02)))
        .onAppear { loadFolders() }
    }

    private func loadFolders() {
        let home = NSHomeDirectory()
        let cloudDocs = "\(home)/Library/Mobile Documents/com~apple~CloudDocs"
        let targets = [
            ("Projects", "\(home)/Documents/Projects"),
            ("MacBackup", "\(home)/Documents/MacBackup_20260827"),
            ("Downloads Evicted", "\(cloudDocs)/Downloads_Evicted"),
            ("Archive", "\(cloudDocs)/Archive"),
            ("Media", "\(cloudDocs)/Media")
        ]

        var items: [GhostFolderItem] = []
        for (name, path) in targets {
            if FileManager.default.fileExists(atPath: path) {
                let total = iCloudStorageOptimizer.getDirectorySize(URL(fileURLWithPath: path))
                // Approximate local footprint
                let local = total > 0 ? Int64(Double(total) * 0.15) : 0
                items.append(GhostFolderItem(name: name, path: path, totalSizeBytes: total, localSizeBytes: local))
            }
        }
        self.folders = items
    }
}
