import SwiftUI

struct SpotlightPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selectedTab: SearchResultCategory? = nil
    @State private var results: [SearchResultCategory: [SearchResultItem]] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                TextField("Ask Lumen Copilot or search lifelog (e.g. Steve Credit, CAVA, what did I build?)…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .onChange(of: query) {
                        performSearch(query)
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                        results = [:]
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }

                Button { dismiss() } label: {
                    Text("ESC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "#1A1B23"))

            Divider().opacity(0.3)

            // Results & Copilot View
            if query.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .top, endPoint: .bottom))
                    Text("Lumen Neural Copilot & Lifelog")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Ask questions or search: “Steve Credit”, “CAVA”, “what did I build?”, “tax deductions”.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Lumen Copilot Card
                        copilotCard

                        ForEach(SearchResultCategory.allCases) { cat in
                            if let items = results[cat], !items.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.accent)
                                        Text(cat.rawValue.uppercased())
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.45))
                                            .tracking(1)
                                        Spacer()
                                        Text("\(items.count)")
                                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }

                                    VStack(spacing: 6) {
                                        ForEach(items) { item in
                                            resultRow(item)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(width: 600, height: 480)
        .background(Color(hex: "#14151B"))
    }

    private var copilotCard: some View {
        let appState = AppState.shared
        let copilot = LumenCopilotEngine.ask(
            query: query,
            stats: appState.stats,
            spendMonth: appState.spendMonth,
            taxReport: appState.taxReport2026,
            forecast: appState.financialForecast
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#FBBF24"))
                Text(copilot.title.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#FBBF24"))
                    .tracking(1)
                Spacer()
                Text("LUMEN SYNTHESIS")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
            }

            Text(copilot.answer)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(copilot.bulletPoints, id: \.self) { pt in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(AppTheme.accent)
                        Text(pt).font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#1A1829"), Color(hex: "#14151C")], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "#FBBF24").opacity(0.25), lineWidth: 1)
        )
    }

    private var totalResultCount: Int {
        results.values.reduce(0) { $0 + $1.count }
    }

    private func performSearch(_ text: String) {
        results = LifelogSearchEngine.search(query: text)
    }

    private func resultRow(_ item: SearchResultItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: item.colorHex))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color(hex: item.colorHex).opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let badge = item.badge {
                        Text(badge)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.15)))
                    }
                }
                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
    }
}
