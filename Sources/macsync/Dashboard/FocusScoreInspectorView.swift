import SwiftUI

public struct FocusScoreInspectorView: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        let stats = appState.stats
        let score = stats.focusScore
        let liveKeys = max(stats.keystrokes, appState.liveKeystrokes)

        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: max(0.01, Double(score) / 100.0))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#FBBF24"))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(score)/100")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(stats.focusScoreLabel.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(hex: "#FBBF24"))
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Capsule().fill(Color(hex: "#FBBF24").opacity(0.18)))
                    }
                    Text("Live Cognitive Telemetry Engine")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Divider().opacity(0.2)

            // Why is it styled this way?
            VStack(alignment: .leading, spacing: 4) {
                Text("ABOUT THIS CIRCLE")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(0.8)
                Text("The outer ring represents your flow state capacity. The glowing amber arc tracks your active deep work ratio, typing velocity, and context switching resilience in real time.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Real-time Metrics Grid
            HStack(spacing: 8) {
                metricCell(title: "Active Work", value: "\(Int(stats.activeMinutes))m", icon: "clock.fill", color: AppTheme.accent)
                metricCell(title: "Live Keystrokes", value: "\(liveKeys)", icon: "keyboard.fill", color: AppTheme.tileKey)
                metricCell(title: "Meetings", value: "\(Int(stats.meetingMinutes))m", icon: "video.fill", color: .orange)
            }

            // 1-Click Floating HUD / Shield Toggle
            Button {
                appState.toggleHUD()
            } label: {
                HStack {
                    Image(systemName: "macwindow.on.rectangle")
                    Text(appState.isHUDVisible ? "Hide Floating Glass HUD" : "Pin Floating Glass HUD")
                }
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 300)
        .background(Color(hex: "#14151C"))
    }

    private func metricCell(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(color)
                Text(title).font(.system(size: 8.5)).foregroundStyle(.white.opacity(0.45))
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
    }
}
