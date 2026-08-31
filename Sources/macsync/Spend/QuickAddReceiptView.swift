import SwiftUI

struct QuickAddReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState = AppState.shared

    @State private var merchant: String = ""
    @State private var amountString: String = ""
    @State private var selectedCategory: ReceiptCategory = .shopping
    @State private var selectedCard: String = "8031"
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()

    private let standardCards = ["8031", "7805", "9530", "1533", "1244", "Direct"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Add Purchase", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                // Merchant & Amount
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MERCHANT").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        TextField("e.g. Best Buy, CAVA", text: $merchant)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                            .font(.system(size: 13))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AMOUNT ($)").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        TextField("0.00", text: $amountString)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(width: 100)
                }

                // Category & Card
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CATEGORY").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        Picker("", selection: $selectedCategory) {
                            ForEach(ReceiptCategory.assignable) { cat in
                                HStack {
                                    Image(systemName: cat.icon)
                                    Text(cat.label)
                                }.tag(cat)
                            }
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PAYMENT CARD").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        Picker("", selection: $selectedCard) {
                            ForEach(standardCards, id: \.self) { c in
                                Text(c == "Direct" ? "Direct Web" : "\(CardPortfolio.shortName(for: c)) (••\(c))").tag(c)
                            }
                        }
                        .labelsHidden()
                    }
                }

                // Date
                VStack(alignment: .leading, spacing: 4) {
                    Text("DATE").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                    DatePicker("", selection: $transactionDate, displayedComponents: [.date])
                        .labelsHidden()
                }

                // Notes / Item Description
                VStack(alignment: .leading, spacing: 4) {
                    Text("ITEM / NOTES").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                    TextField("e.g. 40in Insignia TV, Lunch bowl", text: $notes)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                        .font(.system(size: 12))
                }
            }

            Spacer()

            // Save Button
            Button {
                savePurchase()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark")
                    Text("Save Purchase").font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(merchant.trimmingCharacters(in: .whitespaces).isEmpty || Decimal(string: amountString) == nil)
        }
        .padding(18)
        .frame(width: 380, height: 360)
        .background(Color(hex: "#16171D"))
    }

    private func savePurchase() {
        guard let amt = Decimal(string: amountString), amt > 0 else { return }
        let cleanMerchant = merchant.trimmingCharacters(in: .whitespaces)
        guard !cleanMerchant.isEmpty else { return }

        let cardToken = (selectedCard == "Direct") ? nil : selectedCard

        let payload = ReceiptPayload(
            id: UUID(),
            merchant: cleanMerchant,
            amount: amt,
            currency: "USD",
            cardLast4: cardToken,
            category: selectedCategory,
            transactionDate: transactionDate,
            capturedAt: Date(),
            source: "manual",
            mailMessageID: nil,
            confidence: 1.0,
            needsReview: false,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )

        let event = TrackerEvent(
            ts: transactionDate,
            kind: .receipt,
            payload: .receipt(payload)
        )

        DataStore.shared.append(event)
        appState.refreshSpend()
        dismiss()
    }
}
