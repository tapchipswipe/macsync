import SwiftUI

public struct StorageHelperView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isOptimizing = false
    @State private var statusMessage: String? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("iCloud Storage Optimizer", systemImage: "icloud.and.arrow.up.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#5B8CFF"))
                Spacer()
                Text("ZERO-LOCAL FOOTPRINT")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
            }

            // Storage Overview Bar
            let s = appState.storageSnapshot
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(s.freeDiskFormatted) Free of \(s.totalDiskFormatted)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(s.diskUsagePercentage >= 90 ? .orange : .white)
                    Spacer()
                    Text("\(Int(s.diskUsagePercentage))% Used")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Multi-Segment Gauge
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let usedPct = min(1.0, max(0.0, Double(s.usedDiskBytes) / Double(max(1, s.totalDiskBytes))))
                    let reclaimPct = min(usedPct, Double(s.reclaimableBytes) / Double(max(1, s.totalDiskBytes)))
                    let nonReclaimPct = max(0.0, usedPct - reclaimPct)

                    HStack(spacing: 2) {
                        // Regular used space
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color(hex: "#4F46E5"), Color(hex: "#3B82F6")], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, totalWidth * nonReclaimPct))

                        // Reclaimable / Offloadable space
                        if reclaimPct > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(4, totalWidth * reclaimPct))
                        }

                        // Free space
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
            }

            // Metrics Summary Cards
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.reclaimableFormatted)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#FBBF24"))
                    Text("Reclaimable Now").font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(s.iCloudEvictedFormatted)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.batteryGreen)
                    Text("iCloud Offloaded").font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
            }

            Text(s.statusNarrative)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.65))

            // 1-Click Action Buttons
            HStack(spacing: 8) {
                Button {
                    runOptimizationAction {
                        appState.optimizeAllStorage()
                    }
                } label: {
                    Label(isOptimizing ? "Optimizing…" : "1-Click Cloud Evict", systemImage: "icloud.and.arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.small)
                .disabled(isOptimizing)

                Button {
                    runOptimizationAction {
                        appState.purgeCaches()
                    }
                } label: {
                    Label("Clean Caches", systemImage: "trash.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.7))
                .controlSize(.small)
                .disabled(isOptimizing)
            }

            if let msg = statusMessage {
                Text(msg)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(AppTheme.batteryGreen)
            }

            // Candidates List
            if !s.candidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OPTIMIZATION TARGETS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.5)

                    ForEach(s.candidates.prefix(4)) { candidate in
                        HStack(spacing: 8) {
                            Image(systemName: candidate.category.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(categoryColor(candidate.category))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(candidate.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(candidate.detail)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(candidate.sizeFormatted)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))

                            Button {
                                appState.optimizeSpecificCandidate(candidate)
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func runOptimizationAction(action: @escaping () -> Void) {
        isOptimizing = true
        statusMessage = "Processing storage optimization in background…"
        DispatchQueue.global(qos: .userInitiated).async {
            action()
            DispatchQueue.main.async {
                isOptimizing = false
                statusMessage = "✓ Optimization complete. Local disk space reclaimed."
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    statusMessage = nil
                }
            }
        }
    }

    private func categoryColor(_ cat: StorageCategory) -> Color {
        switch cat {
        case .iCloudEvictable: return Color(hex: "#5B8CFF")
        case .duplicateFile: return .orange
        case .cachePurge: return Color(hex: "#F43F5E")
        case .downloadsArchive: return Color(hex: "#63E6BE")
        case .largeMedia: return Color(hex: "#FBBF24")
        }
    }
}
