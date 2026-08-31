import SwiftUI

struct TimeMachineScrubberView: View {
    let frames: [TimeMachineFrame]
    @State private var selectedMinute: Double = 720 // Default to 12:00 PM

    private var currentFrame: TimeMachineFrame? {
        let target = (Int(selectedMinute) / 5) * 5
        return frames.first(where: { $0.minuteOfDay == target }) ?? frames.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Attention Time Machine", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                if let frame = currentFrame {
                    Text(frame.timeString)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AppTheme.accent.opacity(0.2)))
                }
            }

            // 24h Heatmap Strip
            HStack(spacing: 1) {
                ForEach(frames.filter { $0.minuteOfDay % 15 == 0 }) { f in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(heatColor(for: f.intensity))
                        .frame(height: 18)
                }
            }

            // Scrubber Slider
            Slider(value: $selectedMinute, in: 0...1435, step: 5)
                .tint(AppTheme.accent)

            // Current Frame Snapshot Inspector
            if let frame = currentFrame {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(frame.activeApp ?? "Idle / Screen Off")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        if let title = frame.windowTitle {
                            Text(title)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if let git = frame.gitCommit {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                            Text(git)
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color(hex: "#FBBF24"))
                        .lineLimit(1)
                    }

                    if frame.keystrokes > 0 {
                        Text("\(frame.keystrokes) keys")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.tileKey)
                    }

                    if let spend = frame.purchaseAmount, let merchant = frame.purchaseMerchant {
                        Text("\(merchant) · \(SpendFormat.amount(spend))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#63E6BE"))
                    }

                    if frame.inCall {
                        Text("In Meeting")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func heatColor(for intensity: Double) -> Color {
        if intensity == 0 { return Color.white.opacity(0.06) }
        if intensity < 0.3 { return Color(hex: "#5B8CFF").opacity(0.4) }
        if intensity < 0.7 { return Color(hex: "#5B8CFF").opacity(0.8) }
        return Color(hex: "#FBBF24")
    }
}
