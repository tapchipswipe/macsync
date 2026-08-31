import SwiftUI

struct FinancialRunwayView: View {
    let forecast: FinancialForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Predictive Runway & Tax Savings", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#63E6BE"))
                Spacer()
                Text("ML FORECAST")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SpendFormat.amount(forecast.projectedMonthEndSpend))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(forecast.isUnderBudget ? AppTheme.batteryGreen : .orange)
                    Text("Projected Month-End").font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.45))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(SpendFormat.amount(forecast.estimatedTaxSavings))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#5B8CFF"))
                    Text("Est. Tax Savings (28%)").font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.45))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(SpendFormat.amount(forecast.dailyBurnRate) + "/d")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Daily Burn Rate").font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.45))
                }
            }

            Text(forecast.forecastNarrative)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
    }
}
