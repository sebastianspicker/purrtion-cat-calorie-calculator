import Foundation

/// The energy estimator (ENGINE.md §3). It never reads or writes `targetKcal` except for the comparison.
public enum Estimator {
    private typealias M = EnergyModel
    /// RER = 70 × w^0.75. A reference, not a feeding recommendation.
    public static func rer(_ weightKg: Double) throws -> Double {
        guard weightKg.isFinite, weightKg > 0 else { throw PlanError("Weight must be positive and finite") }
        return M.Rer.factor * pow(weightKg, M.Rer.exponent)
    }
    /// MER(k, w) = k × w^0.67
    public static func mer(_ k: Double, _ weightKg: Double) -> Double { k * pow(weightKg, M.Mer.exponent) }

    /// Weight-log entries dated on or before `asOf`, sorted by date then id.
    public static func weightEntries(_ cat: Cat, asOf: String) throws -> [WeightEntry] {
        try cat.weightLog.filter { try Dates.daysBetween($0.date, asOf) >= 0 }
            .sorted { $0.date != $1.date ? $0.date < $1.date : $0.id < $1.id }
    }
    /// Age in days on `asOf`; nil when unknown or when the birth date lies after `asOf`.
    public static func ageInDays(_ profile: Profile, asOf: String) throws -> Double? {
        if let birth = profile.birthDate { let days = try Dates.daysBetween(birth, asOf); return days < 0 ? nil : days }
        return profile.approxAgeYears.map { $0 * M.Units.daysPerYear }
    }
    /// The profile BCS (the owner's current assessment) when set; otherwise the BCS of the latest weight-log entry
    /// dated on or before `asOf` that has one.
    public static func effectiveBcs(_ cat: Cat, asOf: String) throws -> Int? {
        if let bcs = cat.profile.bcs { return bcs }
        return try weightEntries(cat, asOf: asOf).last { $0.bcs != nil }?.bcs
    }
    /// Reaching an estimated adult weight does not establish maturity; the growth estimate needs review.
    public static func hasReachedExpectedAdultWeight(_ cat: Cat, asOf: String) throws -> Bool {
        guard let days = try ageInDays(cat.profile, asOf: asOf), let adult = cat.profile.expectedAdultWeightKg else { return false }
        return days >= M.Age.neonateMaxDays && days / M.Units.daysPerMonth < M.Age.kittenMaxMonths && cat.weightKg >= adult
    }
    public static func stageOf(_ cat: Cat, asOf: String) throws -> Stage? {
        let p = cat.profile
        let days = try ageInDays(p, asOf: asOf)
        if p.endOfLife { return .endOfLife }
        if p.reproduction.status == .gestation { return .gestation }
        if p.reproduction.status == .lactation { return .lactation }
        guard let days else { return nil }
        if days < M.Age.neonateMaxDays { return .neonate }
        if days / M.Units.daysPerMonth < M.Age.kittenMaxMonths { return .kitten }
        return floor(days / M.Units.daysPerYear) >= M.Age.seniorMinYears ? .senior : .adult
    }
    private static func lifeStageLabel(_ years: Double) -> LifeStageLabel {
        years < M.Age.youngAdultMinYears ? .kitten : years < M.Age.matureAdultMinYears ? .youngAdult
            : years < M.Age.seniorLabelMinYears ? .matureAdult : .senior
    }
    public static func isRecentlyNeutered(_ profile: Profile, asOf: String) throws -> Bool {
        guard let date = profile.neuteredDate else { return false }
        let days = try Dates.daysBetween(date, asOf)
        return days >= 0 && days <= M.Age.recentNeuterMaxDays
    }
    /// Lifestyle coefficient k; a missing lifestyle defaults from neuter status (neutered → typical, otherwise active).
    public static func lifestyleK(_ profile: Profile) -> Double {
        switch profile.lifestyle ?? (profile.neutered == .yes ? .typical : .active) {
        case .sedentary: M.Mer.sedentary
        case .typical: M.Mer.typical
        case .active: M.Mer.active
        }
    }
    /// A stored ideal weight is used as-is (D3); otherwise it is derived from the effective BCS, else the current weight.
    public static func idealWeightOf(_ cat: Cat, bcs: Int?) -> IdealWeight {
        let bw = cat.weightKg, iw = M.IdealWeight.self
        if let stored = cat.profile.idealWeightKg {
            return cat.profile.idealWeightSource == .estimate
                ? IdealWeight(kg: stored, lowKg: stored * (1 - iw.rangeFraction), highKg: stored * (1 + iw.rangeFraction), source: .estimate)
                : IdealWeight(kg: stored, lowKg: stored, highKg: stored, source: .veterinarian)
        }
        if let bcs, Double(bcs) >= M.Bcs.overweightMin {
            let kg = bw / (1 + iw.fractionPerBcsUnit * (Double(bcs) - M.Bcs.ideal))
            return IdealWeight(kg: kg, lowKg: kg * (1 - iw.rangeFraction), highKg: kg * (1 + iw.rangeFraction), source: .bcsEstimate)
        }
        return IdealWeight(kg: bw, lowKg: bw, highKg: bw, source: .current)
    }
    /// Weight used by the maintenance and gain equations (D2): the ideal weight when it is below the current weight.
    public static func weightUsed(_ bw: Double, _ ibw: Double) -> Double { ibw < bw ? ibw : bw }
    /// Piecewise-linear FEDIAF kitten band multiplier between the band centres (D4).
    public static func kittenBandMultiplier(_ months: Double, _ values: [Double]) -> Double {
        let centres = M.Kitten.bandCentreMonths
        if months <= centres[0] { return values[0] }
        for i in 0..<(centres.count - 1) {
            let c0 = centres[i], c1 = centres[i + 1]
            if months <= c1 { return values[i] + (months - c0) / (c1 - c0) * (values[i + 1] - values[i]) }
        }
        return values[values.count - 1]
    }
    private static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
    /// Weight-loss start (D1); nil when a verified intake lies below the floor (refer).
    public static func weightLossStartKcal(ibwKg: Double, k: Double, verifiedIntakeKcal: Double?, floorKcal: Double) throws -> Double? {
        typealias L = M.Loss
        let rerIdeal = try rer(ibwKg)
        guard let verified = verifiedIntakeKcal else { return max(floorKcal, L.startFactor * min(rerIdeal, mer(k, ibwKg))) }
        return verified < floorKcal ? nil : max(floorKcal, L.verifiedIntakeFactor * verified)
    }
    /// Maintenance start at weight w: MER(k, w), capped at 1.4 × RER(BW), never below the floor.
    public static func maintainStartKcal(_ cat: Cat, weightKg: Double, floorKcal: Double) throws -> (kcal: Double, clamped: Bool) {
        let raw = mer(lifestyleK(cat.profile), weightKg), cap = M.Maintain.maxRerMultiple * (try rer(cat.weightKg))
        return (max(min(raw, cap), floorKcal), raw > cap)
    }

    private struct Calculation {
        var equation: EquationId, coefficient: Double?, weightUsedKg: Double
        var startKcal: Double, lowKcal: Double, highKcal: Double
    }
    private static func sorted<T: RawRepresentable & Hashable>(_ set: Set<T>) -> [T] where T.RawValue == String {
        set.sorted { $0.rawValue < $1.rawValue }
    }

    public static func estimate(_ cat: Cat, asOf: String, trendStops: [ReferCode] = []) throws -> EnergyEstimate {
        let p = cat.profile, bw = cat.weightKg, days = try ageInDays(p, asOf: asOf), bcs = try effectiveBcs(cat, asOf: asOf)
        let stageOpt = try stageOf(cat, asOf: asOf), years = days.map { floor($0 / M.Units.daysPerYear) }
        var reasons = Set(trendStops), missing = Set<InputCode>(), notes = Set<NoteCode>()
        if stageOpt == .kitten, try hasReachedExpectedAdultWeight(cat, asOf: asOf) { reasons.insert(.kittenAdultWeightReached) }
        if let days, days < M.Age.neonateMaxDays { reasons.insert(.neonate) }
        if p.endOfLife { reasons.insert(.endOfLife) }
        if p.medical.contains(where: \.isAcute) { reasons.insert(.acuteMedical) }
        if let bcs, Double(bcs) <= M.Bcs.referMax { reasons.insert(.bcsLow) }
        if p.mcs == .severe { reasons.insert(.mcsSevere) }
        let adultLike = stageOpt == .adult || stageOpt == .senior
        if days == nil { missing.insert(.age) }
        if adultLike && p.neutered == .unknown { missing.insert(.neutered) }
        if adultLike && bcs == nil { missing.insert(.bcs) }
        if let years, years >= M.Age.mcsRequiredMinYears, p.mcs == nil { missing.insert(.mcs) }
        if p.reproduction.status == .lactation {
            if p.reproduction.litterSize == nil { missing.insert(.litterSize) }
            if p.reproduction.lactationWeek == nil { missing.insert(.lactationWeek) }
        }
        let rerKcal = try rer(bw)
        func result(status: EstimateStatus, idealWeight: IdealWeight? = nil, calc: Calculation? = nil, floorKcal: Double? = nil,
                    referenceBand: ReferenceBand? = nil, comparison: Comparison? = nil) -> EnergyEstimate {
            EnergyEstimate(status: status, stage: stageOpt, lifeStageLabel: years.map(lifeStageLabel), ageMonths: days.map { $0 / M.Units.daysPerMonth },
                           rerKcal: rerKcal, idealWeight: idealWeight, equation: calc?.equation, coefficient: calc?.coefficient,
                           weightUsedKg: calc?.weightUsedKg, startKcal: calc?.startKcal, lowKcal: calc?.lowKcal, highKcal: calc?.highKcal,
                           floorKcal: floorKcal, referenceBand: referenceBand, reasons: sorted(reasons), missing: sorted(missing),
                           notes: sorted(notes), comparison: comparison)
        }
        guard reasons.isEmpty, missing.isEmpty, let stage = stageOpt, let days else {
            return result(status: reasons.isEmpty ? .needsInput : .refer)
        }
        let chronic = p.medical.contains { !$0.isAcute }
        if chronic { notes.insert(.medicalVetPlan); if p.medical.contains(.diabetes) { notes.insert(.diabetesLowCarbInfo) } }
        let calc: Calculation
        var idealWeight: IdealWeight? = nil, floorKcal: Double? = nil, referenceBand: ReferenceBand? = nil
        switch stage {
        case .kitten:
            typealias K = M.Kitten
            let months = days / M.Units.daysPerMonth
            let bandLow = kittenBandMultiplier(months, K.bandLow) * mer(K.bandLowK, bw)
            let bandHigh = kittenBandMultiplier(months, K.bandHigh) * mer(K.bandHighK, bw)
            let merAdult = mer(lifestyleK(p), bw), ageTerm = (months - K.transitionStartMonths) / K.transitionMonthsWidth
            let base: Double, t: Double, equation: EquationId, coefficient: Double?
            if let adult = p.expectedAdultWeightKg {
                // Reached/exceeded adult-weight estimates are referred above, so ratio < 1 here.
                let ratio = bw / adult
                base = mer(K.nrcK, bw) * K.nrcFactor * (exp(K.nrcExponent * ratio) - K.nrcOffset)
                t = clamp01(max((ratio - K.transitionStartRatio) / K.transitionRatioWidth, ageTerm))
                equation = .kittenNrc; coefficient = K.nrcK
            } else {
                notes.insert(.kittenAdultWeightUnknown)
                base = (bandLow + bandHigh) / 2; t = clamp01(ageTerm)
                equation = .kittenFediafBand; coefficient = nil
            }
            let raw = (1 - t) * base + t * merAdult, cap = K.maxRerMultiple * rerKcal
            if raw > cap { notes.insert(.clampedHigh) }
            let start = min(raw, cap)
            var low = min(K.startLowFactor * start, bandLow), high = max(K.startHighFactor * start, bandHigh)
            if t > 0 { low = min(low, M.Maintain.lowFactor * merAdult); high = max(high, M.Maintain.highFactor * merAdult) }
            if t > 0 && t < 1 { notes.insert(.kittenTransition) }
            calc = Calculation(equation: equation, coefficient: coefficient, weightUsedKg: bw, startKcal: start, lowKcal: low, highKcal: high)
            notes.insert(.kittenWeighWeekly)
        case .gestation:
            typealias G = M.Gestation
            let w = p.reproduction.preBreedingWeightKg ?? bw
            if p.reproduction.preBreedingWeightKg == nil { notes.insert(.preBreedingWeightAssumed) }
            let start = mer(G.k, w)
            calc = Calculation(equation: .gestationFediaf, coefficient: G.k, weightUsedKg: w, startKcal: start, lowKcal: start, highKcal: G.highFactor * start)
            notes.insert(.freeChoiceRecommended); notes.insert(.reproductionVet)
        case .lactation:
            typealias L = M.Lactation
            let litter = Double(p.reproduction.litterSize!), week = p.reproduction.lactationWeek! // Presence was checked above.
            let tier = L.litterMax.firstIndex { litter <= $0 } ?? L.litterC.count - 1
            let factor = week <= L.weekFactors.count ? L.weekFactors[week - 1] : L.lateWeekFactor
            if week > L.weekFactors.count { notes.insert(.weaningTransition) }
            let start = mer(L.k, bw) + L.litterC[tier] * bw * factor
            calc = Calculation(equation: .lactationFediaf, coefficient: L.k, weightUsedKg: bw, startKcal: start, lowKcal: start, highKcal: L.highFactor * start)
            notes.insert(.freeChoiceRecommended); notes.insert(.reproductionVet)
        default:
            let effective = bcs!, ibw = idealWeightOf(cat, bcs: effective), floor = M.Floor.rerFactor * (try rer(ibw.kg)) // Missing BCS returned above.
            let k = lifestyleK(p), overweight = Double(effective) >= M.Bcs.overweightMin
            let wider = years! >= M.Age.widerRangeMinYears
            func maintain(_ w: Double) throws -> Calculation {
                let start = try maintainStartKcal(cat, weightKg: w, floorKcal: floor)
                if start.clamped { notes.insert(.clampedHigh) }
                if wider { notes.insert(.seniorWiderRange) }
                return Calculation(equation: .adultFediaf, coefficient: k, weightUsedKg: w, startKcal: start.kcal,
                                   lowKcal: max(start.kcal * M.Maintain.lowFactor, floor),
                                   highKcal: start.kcal * (wider ? M.Maintain.seniorHighFactor : M.Maintain.highFactor))
            }
            let w = weightUsed(bw, ibw.kg)
            if chronic { calc = try maintain(bw) }
            else if cat.goal == .loss {
                if ibw.kg < bw {
                    typealias L = M.Loss
                    // A weight-stable cat that eats less than the floor needs a work-up, not a further cut (D1).
                    guard let start = try weightLossStartKcal(ibwKg: ibw.kg, k: k, verifiedIntakeKcal: p.verifiedIntakeKcal, floorKcal: floor) else {
                        reasons.insert(.verifiedIntakeBelowFloor); notes.removeAll()
                        return result(status: .refer)
                    }
                    calc = Calculation(equation: .weightLossAaha, coefficient: L.startFactor, weightUsedKg: ibw.kg, startKcal: start,
                                       lowKcal: max(start * L.lowFactor, floor), highKcal: start * L.highFactor)
                } else { calc = try maintain(w); notes.insert(.lossNotIndicated) }
            } else if cat.goal == .gain {
                if Double(effective) == M.Bcs.gainOnly {
                    typealias G = M.Gain
                    let m = mer(k, w)
                    calc = Calculation(equation: .adultGain, coefficient: k, weightUsedKg: w, startKcal: max(G.startFactor * m, floor),
                                       lowKcal: max(G.lowFactor * m, floor), highKcal: max(G.highFactor * m, floor))
                } else { calc = try maintain(w); notes.insert(.gainNotIndicated) }
            } else {
                calc = try maintain(w)
                if overweight { notes.insert(.overweightConsiderLoss) }
            }
            if try isRecentlyNeutered(p, asOf: asOf) { notes.insert(.recentlyNeutered) }
            idealWeight = ibw; floorKcal = floor
            referenceBand = ReferenceBand(lowKcal: mer(M.Mer.referenceBandLow, calc.weightUsedKg), highKcal: mer(M.Mer.referenceBandHigh, calc.weightUsedKg))
        }
        let target = cat.targetKcal, ratio = target / calc.startKcal
        let comparison = Comparison(targetToStartRatio: ratio, belowRange: target < calc.lowKcal, aboveRange: target > calc.highKcal,
                                    differsOver30Percent: abs(ratio - 1) > M.Comparison.differsFraction,
                                    belowFloor: floorKcal.map { target < $0 } ?? false)
        return result(status: chronic || stage == .gestation || stage == .lactation ? .referenceOnly : .ok,
                      idealWeight: idealWeight, calc: calc, floorKcal: floorKcal, referenceBand: referenceBand, comparison: comparison)
    }
}
