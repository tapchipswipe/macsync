import SwiftUI
import Charts

struct DailySpendingChartView: View {
    let trajectory: [DaySpendPoint]
    let baselineMonthly: Decimal

    @State private var selectedDay: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily Spend Trajectory", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let sel = selectedDay, let pt = trajectory.first(where: { $0.day == sel }) {
                    Text("Day \(pt.day): \(SpendFormat.amount(pt.amount)) (Total: \(SpendFormat.amount(pt.cumulativeAmount)))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Text("Cumulative Burn Curve")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            if trajectory.isEmpty {
                Text("No daily spending recorded yet this month.")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    .frame(height: 100)
            } else {
                Chart {
                    // Daily spending bars
                    ForEach(trajectory) { pt in
                        BarMark(
                            x: .value("Day", pt.day),
                            y: .value("Daily Spend", NSDecimalNumber(decimal: pt.amount).doubleValue)
                        )
                        .foregroundStyle(Color(hex: "#5B8CFF").opacity(0.6))
                        .cornerRadius(2)

                        // Cumulative spending line
                        LineMark(
                            x: .value("Day", pt.day),
                            y: .value("Cumulative Spend", NSDecimalNumber(decimal: pt.cumulativeAmount).doubleValue)
                        )
                        .foregroundStyle(Color(hex: "#63E6BE"))
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Day", pt.day),
                            y: .value("Cumulative Spend", NSDecimalNumber(decimal: pt.cumulativeAmount).doubleValue)
                        )
                        .foregroundStyle(Color(hex: "#63E6BE"))
                        .symbolSize(12)
                    }

                    // Baseline reference rule
                    RuleMark(y: .value("Baseline", NSDecimalNumber(decimal: baselineMonthly).doubleValue))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Monthly Baseline: \(SpendFormat.amount(baselineMonthly))")
                                .font(.system(size: 8.5))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                }
                .chartXScale(domain: 1...max(28, trajectory.last?.day ?? 30))
                .chartXAxis {
                    AxisMarks(values: [1, 5, 10, 15, 20, 25, 30]) { val in
                        AxisValueLabel {
                            if let d = val.as(Int.self) {
                                Text("\(d)").font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text("$\(Int(v))").font(.system(size: 8.5, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                            }
                        }
                    }
                }
                .frame(height: 120)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
    }
}
