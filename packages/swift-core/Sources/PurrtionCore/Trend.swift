import Foundation

/// Monitoring and adjustment (ENGINE.md §6).
public enum TrendAnalysis {
    private typealias T = EnergyModel.Trend
    public struct WeightSeries: Sendable {
        public let entries: [WeightEntry]
        public let latest: WeightEntry?
        public let window: [WeightEntry]
        public let spanDays: Double
        public let ratePercentPerWeek: Double?
        public let change28dPercent: Double?
    }
    /// Window, least-squares rate and 28-day change from the entries dated on or before `asOf`.
    public static func weightSeries(_ cat: Cat, asOf: String) throws -> WeightSeries {
        let entries = try Estimator.weightEntries(cat, asOf: asOf)
        guard let latest = entries.last else {
            return WeightSeries(entries: entries, latest: nil, window: [], spanDays: 0, ratePercentPerWeek: nil, change28dPercent: nil)
        }
        let window = try entries.filter { try Dates.daysBetween($0.date, latest.date) <= T.windowDays }
        let first = window[0], spanDays = try Dates.daysBetween(first.date, latest.date)
        var rate: Double?, change: Double?
        if window.count >= 2 && spanDays >= T.rateMinSpanDays {
            let xs = try window.map { try Dates.daysBetween(first.date, $0.date) }, ys = window.map(\.weightKg)
            func mean(_ values: [Double]) -> Double { values.reduce(0, +) / Double(values.count) }
            let mx = mean(xs), my = mean(ys)
            var sxy = 0.0, sxx = 0.0
            for (i, x) in xs.enumerated() { sxy += (x - mx) * (ys[i] - my); sxx += (x - mx) * (x - mx) }
            rate = sxy / sxx * 7 / my * 100
        }
        if window.count >= 2 && spanDays >= T.changeMinSpanDays { change = (latest.weightKg - first.weightKg) / first.weightKg * 100 }
        return WeightSeries(entries: entries, latest: latest, window: window, spanDays: spanDays, ratePercentPerWeek: rate, change28dPercent: change)
    }
    /// Trend stops that feed into `estimate.reasons`.
    public static func stops(_ cat: Cat, series: WeightSeries, stage: Stage?) throws -> [ReferCode] {
        var stops: [ReferCode] = []
        let rate = series.ratePercentPerWeek, change = series.change28dPercent
        // Growth, pregnancy and lactation change weight by design; the rapid-change stop is for unintended change only.
        let growing = stage == .kitten || stage == .gestation || stage == .lactation
        let rapid: Bool
        // On a weight-loss plan, loss itself is intended; only a gain or a loss that is too fast stops the plan (D5).
        if cat.goal == .loss {
            rapid = (change.map { $0 >= T.rapidChangePercent || $0 <= T.lossRapidChangePercent } ?? false) || (rate.map { $0 < T.lossRapidRatePercent } ?? false)
        }
        else { rapid = (change.map { abs($0) >= T.rapidChangePercent } ?? false) || (rate.map { $0 < T.rapidLossRatePercent } ?? false) }
        if !growing && rapid { stops.append(.rapidWeightChange) }
        if stage == .kitten, let latest = series.latest {
            let earlier = try series.entries.last {
                let days = try Dates.daysBetween($0.date, latest.date)
                return days >= T.kittenLookbackMinDays && days <= T.kittenLookbackMaxDays
            }
            if let earlier, latest.weightKg <= earlier.weightKg { stops.append(.kittenNotGrowing) }
        }
        return stops
    }
    private static func suggest(_ cat: Cat, asOf: String, estimate: EnergyEstimate, series: WeightSeries) throws -> Suggestion? {
        let floor = estimate.floorKcal ?? 0, target = cat.targetKcal
        // Suggestions are defined for adult and senior plans only; kittens grow and queens are reference-only.
        guard estimate.status == .ok, let rate = series.ratePercentPerWeek, estimate.stage == .adult || estimate.stage == .senior else { return nil }
        let increase = max(target * T.increaseFactor, floor), decrease = target * T.decreaseFactor
        // A floor must never turn a requested reduction into an increase (or an unchanged target).
        func reduce(_ reason: SuggestionReason) -> Suggestion {
            decrease < floor ? Suggestion(action: .refer, reason: .atFloor, suggestedKcal: nil)
                : Suggestion(action: .decrease, reason: reason, suggestedKcal: decrease)
        }
        switch cat.goal {
        case .loss:
            let ibw = estimate.idealWeight?.kg ?? cat.weightKg
            if let latest = series.latest, latest.weightKg <= ibw {
                return Suggestion(action: .switchToMaintenance, reason: .idealWeightReached,
                                  suggestedKcal: try Estimator.maintainStartKcal(cat, weightKg: ibw, floorKcal: floor).kcal)
            }
            if rate < T.lossTooFastRate { return Suggestion(action: .increase, reason: .lossTooFast, suggestedKcal: increase) }
            if rate <= T.lossOnTrackSlowestRate { return Suggestion(action: .none, reason: .onTrack, suggestedKcal: nil) }
            if rate <= T.lossSlowRate || series.spanDays < T.plateauMinSpanDays {
                return Suggestion(action: .hold, reason: .slowRecheckTwoWeeks, suggestedKcal: nil)
            }
            return reduce(.plateau)
        case .maintain:
            guard let change = series.change28dPercent else { return nil }
            if change >= T.maintainChangePercent { return reduce(.gaining) }
            if change <= -T.maintainChangePercent { return Suggestion(action: .increase, reason: .losing, suggestedKcal: increase) }
            return Suggestion(action: .none, reason: .stable, suggestedKcal: nil)
        case .gain:
            if let bcs = try Estimator.effectiveBcs(cat, asOf: asOf), Double(bcs) >= EnergyModel.Bcs.ideal {
                return Suggestion(action: .switchToMaintenance, reason: .idealConditionReached, suggestedKcal: nil)
            }
            if rate > T.gainTooFastRate { return reduce(.gainTooFast) }
            if rate <= T.gainStalledRate && series.spanDays >= T.gainStalledMinSpanDays {
                return Suggestion(action: .increase, reason: .notGaining, suggestedKcal: increase)
            }
            return Suggestion(action: .none, reason: .onTrack, suggestedKcal: nil)
        }
    }
    public static func trend(_ cat: Cat, asOf: String, estimate: EnergyEstimate, series: WeightSeries) throws -> Trend {
        let weighIn: Double
        if estimate.stage == .kitten { weighIn = T.weighInKittenDays }
        else if cat.goal == .loss { weighIn = T.weighInLossDays }
        else if cat.goal == .gain { weighIn = T.weighInGainDays }
        // The default cadence (every 4 weeks) must fit inside the inclusive 28-day window (D8), or a maintenance cat never gets a trend.
        else { weighIn = try Estimator.isRecentlyNeutered(cat.profile, asOf: asOf) ? T.weighInRecentlyNeuteredDays : T.weighInOtherDays }
        return Trend(entries: series.entries.count, latestKg: series.latest?.weightKg, ratePercentPerWeek: series.ratePercentPerWeek,
                     change28dPercent: series.change28dPercent, suggestion: try suggest(cat, asOf: asOf, estimate: estimate, series: series),
                     nextWeighInDays: Int(weighIn))
    }
}
