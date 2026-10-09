import Foundation
import PurrtionCore

/// One line of "Why this number": a plain-text formula with the cat's values substituted, plus an optional caption.
struct FormulaLine: Identifiable, Hashable {
    let id: Int
    let text: String
    let caption: String?
}

/// Builds the explanation from `EnergyModel` constants; coefficients are never typed literally (ENGINE.md §8).
enum Formulas {
    private typealias M = EnergyModel

    static func explain(_ cat: Cat, _ e: EnergyEstimate, asOf: String, l: L10n) -> [FormulaLine] {
        var lines: [(String, String?)] = []
        func c(_ value: Double) -> String { l.num(value, digits: 4) }
        func n(_ value: Double, _ digits: Int = 1) -> String { l.num(value, digits: digits) }
        let unit = " \(l.t("unit.kcalPerDay"))", kg = " kg"
        let start = l.t("why.word.start"), range = l.t("why.word.range"), floorWord = l.t("why.word.floor")
        let bw = cat.weightKg, x = M.Mer.exponent
        lines.append(("RER = \(c(M.Rer.factor)) × \(n(bw, 2))^\(c(M.Rer.exponent)) = \(n(e.rerKcal))\(unit)", l.t("why.rer")))
        guard let startKcal = e.startKcal, let low = e.lowKcal, let high = e.highKcal, let equation = e.equation else {
            return number(lines)
        }
        let w = e.weightUsedKg ?? bw, ibw = e.idealWeight
        if ibw?.source == .bcsEstimate, let ibw {
            let bcs = (try? Estimator.effectiveBcs(cat, asOf: asOf)).flatMap { $0 } ?? Int(M.Bcs.ideal)
            lines.append(("IBW = \(n(bw, 2)) ÷ (1 + \(c(M.IdealWeight.fractionPerBcsUnit)) × (\(bcs) − \(Int(M.Bcs.ideal)))) = \(n(ibw.kg, 2))\(kg)",
                          l.t("why.ibw")))
        } else if ibw?.source == .veterinarian, let ibw {
            lines.append(("IBW = \(n(ibw.kg, 2))\(kg)", l.t("why.ibwVet")))
        } else if ibw?.source == .estimate, let ibw {
            lines.append(("IBW = \(n(ibw.kg, 2))\(kg)", l.msg("idealWeight.estimate")))
        }
        func clampedNote(_ raw: Double) {
            if abs(raw - startKcal) > 0.05 { lines.append(("\(start) = \(n(startKcal))\(unit)", l.t("why.clamped"))) }
        }
        switch equation {
        case .adultFediaf, .adultGain:
            let k = e.coefficient ?? M.Mer.typical, mer = Estimator.mer(k, w)
            lines.append(("MER = \(c(k)) × \(n(w, 2))^\(c(x)) = \(n(mer))\(unit)", l.t("why.mer", ["k": n(k, 1)])))
            if equation == .adultGain {
                let raw = M.Gain.startFactor * mer
                lines.append(("\(start) = \(c(M.Gain.startFactor)) × \(n(mer)) = \(n(raw))\(unit)", l.t("why.gain")))
                clampedNote(raw)
            } else { clampedNote(mer) }
        case .weightLossAaha:
            let k = Estimator.lifestyleK(cat.profile)
            if let verified = cat.profile.verifiedIntakeKcal {
                let raw = M.Loss.verifiedIntakeFactor * verified
                lines.append(("\(start) = \(c(M.Loss.verifiedIntakeFactor)) × \(n(verified)) = \(n(raw))\(unit)", l.t("why.verified")))
                clampedNote(raw)
            } else {
                let rerValue = (try? Estimator.rer(w)) ?? 0, merValue = Estimator.mer(k, w), raw = M.Loss.startFactor * min(rerValue, merValue)
                lines.append(("\(start) = \(c(M.Loss.startFactor)) × min(\(n(rerValue)), \(n(merValue))) = \(n(raw))\(unit)", l.t("why.loss")))
                clampedNote(raw)
            }
        case .kittenNrc, .kittenFediafBand:
            let K = M.Kitten.self, months = e.ageMonths ?? 0
            let lowMultiplier = Estimator.kittenBandMultiplier(months, K.bandLow), highMultiplier = Estimator.kittenBandMultiplier(months, K.bandHigh)
            let bandLow = lowMultiplier * Estimator.mer(K.bandLowK, bw), bandHigh = highMultiplier * Estimator.mer(K.bandHighK, bw)
            let ageTerm = (months - K.transitionStartMonths) / K.transitionMonthsWidth
            let base: Double, t: Double
            if equation == .kittenNrc, let adult = cat.profile.expectedAdultWeightKg {
                let ratio = bw / adult
                base = Estimator.mer(K.nrcK, bw) * K.nrcFactor * (exp(K.nrcExponent * ratio) - K.nrcOffset)
                t = min(1, max(0, max((ratio - K.transitionStartRatio) / K.transitionRatioWidth, ageTerm)))
                lines.append(("p = \(n(bw, 2)) ÷ \(n(adult, 2)) = \(n(ratio, 3))", nil))
                lines.append(("NRC = \(c(K.nrcK)) × \(n(bw, 2))^\(c(x)) × \(c(K.nrcFactor)) × (e^(\(c(K.nrcExponent)) × \(n(ratio, 3))) − \(c(K.nrcOffset))) = \(n(base))\(unit)",
                              l.t("why.kittenNrc")))
            } else {
                base = (bandLow + bandHigh) / 2; t = min(1, max(0, ageTerm))
                lines.append(("\(c(lowMultiplier)) × \(c(K.bandLowK)) × \(n(bw, 2))^\(c(x)) = \(n(bandLow))\(unit)", l.t("why.kittenBandLow")))
                lines.append(("\(c(highMultiplier)) × \(c(K.bandHighK)) × \(n(bw, 2))^\(c(x)) = \(n(bandHigh))\(unit)", l.t("why.kittenBandHigh")))
                lines.append(("G = (\(n(bandLow)) + \(n(bandHigh))) ÷ 2 = \(n(base))\(unit)", l.t("why.kittenBandMid")))
            }
            var raw = base
            if t > 0 {
                let merAdult = Estimator.mer(Estimator.lifestyleK(cat.profile), bw)
                raw = (1 - t) * base + t * merAdult
                lines.append(("\(start) = (1 − \(n(t, 2))) × \(n(base)) + \(n(t, 2)) × \(n(merAdult)) = \(n(raw))\(unit)", l.t("why.kittenTransition")))
            }
            clampedNote(raw)
        case .gestationFediaf:
            lines.append(("\(start) = \(c(M.Gestation.k)) × \(n(w, 2))^\(c(x)) = \(n(startKcal))\(unit)", l.t("why.gestation")))
        case .lactationFediaf:
            let L = M.Lactation.self
            let litter = cat.profile.reproduction.litterSize ?? 1, week = cat.profile.reproduction.lactationWeek ?? 1
            let tier = L.litterMax.firstIndex { Double(litter) <= $0 } ?? L.litterC.count - 1
            let factor = week <= L.weekFactors.count ? L.weekFactors[week - 1] : L.lateWeekFactor
            lines.append(("\(start) = \(c(L.k)) × \(n(bw, 2))^\(c(x)) + \(c(L.litterC[tier])) × \(n(bw, 2)) × \(c(factor)) = \(n(startKcal))\(unit)",
                          l.t("why.lactation", ["litter": String(litter), "week": String(week)])))
        @unknown default:
            lines.append(("\(start) = \(n(startKcal))\(unit)", nil))
        }
        lines.append(("\(range) = \(n(low)) – \(n(high))\(unit)", nil))
        if let floorKcal = e.floorKcal, let ibw {
            lines.append(("\(floorWord) = \(c(M.Floor.rerFactor)) × \(c(M.Rer.factor)) × \(n(ibw.kg, 2))^\(c(M.Rer.exponent)) = \(n(floorKcal))\(unit)",
                          l.t("why.floor")))
        }
        return number(lines)
    }
    private static func number(_ lines: [(String, String?)]) -> [FormulaLine] {
        lines.enumerated().map { FormulaLine(id: $0.offset, text: $0.element.0, caption: $0.element.1) }
    }

    /// Short labels for the SCIENCE.md reference numbers used in `EnergyModel.references`.
    static let referenceLabels: [Int: String] = [
        1: "FEDIAF 2025", 2: "NRC 2006", 4: "AAHA 2021", 5: "AAHA 2014", 9: "Merck Veterinary Manual", 13: "Fontaine 2012",
        21: "Hall et al. 2013", 22: "Jewell & Jackson 2023", 25: "Vecchiato et al. 2021", 27: "Menniti et al. 2026",
    ]
    /// "[1] FEDIAF 2025; [2] NRC 2006" for an equation id.
    static func citation(_ id: String) -> String {
        (M.references[id] ?? []).map { ref in
            let label = referenceLabels[ref] ?? ""
            return label.isEmpty ? "[\(ref)]" : "[\(ref)] \(label)"
        }.joined(separator: "; ")
    }
}
