import SwiftUI

struct MorningBriefView: View {
    let brief: MorningBrief

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Morning Executive Brief", systemImage: "sun.max.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.yellow)
                Spacer()
                Text("DAILY BRIEFING")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
            }

            Text(brief.headline)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                // Focus metric
                HStack(spacing: 5) {
                    Image(systemName: "sparkles").font(.system(size: 10)).foregroundStyle(AppTheme.accent)
                    Text("\(brief.yesterdayDeepWorkMinutes / 60)h \(brief.yesterdayDeepWorkMinutes % 60)m focus")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                }

                // Spend metric
                if brief.yesterdaySpend > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "creditcard.fill").font(.system(size: 10)).foregroundStyle(Color(hex: "#63E6BE"))
                        Text("\(SpendFormat.amount(brief.yesterdaySpend)) on \(brief.yesterdayTopCard ?? "Card")")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                    }
                }
            }

            if let renewal = brief.upcomingRenewalNotice {
                HStack(spacing: 5) {
                    Image(systemName: "bell.fill").font(.system(size: 9)).foregroundStyle(.orange)
                    Text(renewal)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#1E1B2E"), Color(hex: "#14151C")], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }
}
