import SwiftUI

struct DayStoryView: View {
    let story: DayStory

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header stats
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(story.totalDeepWorkMinutes / 60)h \(story.totalDeepWorkMinutes % 60)m")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Deep Work").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                }

                if story.totalMeetingMinutes > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(story.totalMeetingMinutes)m")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#FF6B8A"))
                        Text("In-Call").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    }
                }

                if story.totalDaySpend > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SpendFormat.amount(story.totalDaySpend))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#63E6BE"))
                        Text("Day Spend").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                Spacer()
            }

            if story.chapters.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 14)).foregroundStyle(.white.opacity(0.3))
                    Text("No activity chapters recorded yet today.")
                        .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.5))
                }
                .padding(12)
            } else {
                // Connected Timeline
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(story.chapters.enumerated()), id: \.element.id) { idx, chapter in
                        HStack(alignment: .top, spacing: 12) {
                            // Timeline Node & Connecting Line
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(Color(hex: chapter.type.colorHex))
                                    .frame(width: 9, height: 9)
                                    .padding(.top, 4)
                                if idx < story.chapters.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 1.5)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 14)

                            // Content Card
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: chapter.type.icon)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(hex: chapter.type.colorHex))
                                    Text(chapter.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(chapter.timeRangeLabel)
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.45))
                                }

                                Text(chapter.summary)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.75))

                                if let card = chapter.cardNickname {
                                    HStack(spacing: 4) {
                                        Image(systemName: "creditcard.fill").font(.system(size: 8)).foregroundStyle(AppTheme.accent)
                                        Text(card).font(.system(size: 9.5, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.06)))
                                }
                            }
                            .padding(.bottom, 14)
                        }
                    }
                }
            }
        }
    }
}
