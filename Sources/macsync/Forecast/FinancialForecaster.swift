import Foundation

struct FinancialForecast: Codable {
    let currentMonthSpend: Decimal
    let projectedMonthEndSpend: Decimal
    let dailyBurnRate: Decimal
    let daysRemainingInMonth: Int
    let estimatedTaxSavings: Decimal
    let monthlyBudgetBaseline: Decimal
    let budgetDelta: Decimal
    let isUnderBudget: Bool
    let forecastNarrative: String

    static let empty = FinancialForecast(
        currentMonthSpend: 0, projectedMonthEndSpend: 0, dailyBurnRate: 0,
        daysRemainingInMonth: 0, estimatedTaxSavings: 0, monthlyBudgetBaseline: Decimal(string: "350.39")!,
        budgetDelta: 0, isUnderBudget: true, forecastNarrative: "Calculating runway..."
    )
}

enum FinancialForecaster {
    private static let baseline: Decimal = Decimal(string: "350.39")!
    private static let effectiveTaxRate: Decimal = Decimal(string: "0.28")! // 28% federal + state effective rate

    /// Forecasts month-end financial total and tax savings.
    static func computeForecast(spendMonth: SpendSummary, taxReport: ScheduleCTaxReport, date: Date = Date()) -> FinancialForecast {
        let cal = Calendar.current
        let currentDay = cal.component(.day, from: date)
        let totalDays = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        let daysRemaining = max(0, totalDays - currentDay)

        let currentSpend = spendMonth.total
        let pacingBurn = spendMonth.pacing?.dailyBurnRate ?? (currentDay > 0 ? currentSpend / Decimal(currentDay) : 0)

        // Trajectory projection
        let projected = currentSpend + (pacingBurn * Decimal(daysRemaining))
        let delta = projected - baseline
        let isUnder = projected <= baseline

        // Live tax savings
        let taxSavings = taxReport.totalDeductibleAmount * effectiveTaxRate

        let narrative: String
        if isUnder {
            narrative = "Tracking \(SpendFormat.amount(abs(delta))) under $350.39/mo baseline · \(daysRemaining) days left"
        } else {
            narrative = "Tracking \(SpendFormat.amount(delta)) above $350.39/mo baseline · \(daysRemaining) days left"
        }

        return FinancialForecast(
            currentMonthSpend: currentSpend,
            projectedMonthEndSpend: projected,
            dailyBurnRate: pacingBurn,
            daysRemainingInMonth: daysRemaining,
            estimatedTaxSavings: taxSavings,
            monthlyBudgetBaseline: baseline,
            budgetDelta: delta,
            isUnderBudget: isUnder,
            forecastNarrative: narrative
        )
    }
}
