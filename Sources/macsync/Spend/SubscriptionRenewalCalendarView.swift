import SwiftUI

struct SubscriptionRenewalCalendarView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        let renewals = appState.predictedRenewals

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("30-Day Renewal & Price Hike Radar", systemImage: "calendar.badge.clock")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#F59E0B"))
                Spacer()
                Text("\(renewals.count) SCHEDULED")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
            }

            if renewals.isEmpty {
                Text("No recurring subscriptions detected this month.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(renewals.prefix(5)) { r in
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(r.isImminent ? Color.orange.opacity(0.2) : Color.white.opacity(0.06))
                                Image(systemName: r.isImminent ? "bell.badge.fill" : "creditcard.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(r.isImminent ? Color.orange : Color.white.opacity(0.7))
                            }
                            .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(r.merchant)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(.white)
                                    if r.isPriceHike {
                                        Text("HIKE +\(SpendFormat.amount(r.priceHikeDifference))")
                                            .font(.system(size: 7.5, weight: .bold))
                                            .foregroundStyle(.red)
                                            .padding(.horizontal, 3).padding(.vertical, 1)
                                            .background(Capsule().fill(Color.red.opacity(0.15)))
                                    }
                                }
                                Text(r.renewalRelativeFormatted)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(r.isImminent ? Color.orange : .white.opacity(0.45))
                            }

                            Spacer()

                            Text(r.amountFormatted)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#63E6BE"))
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.02)))
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
}
