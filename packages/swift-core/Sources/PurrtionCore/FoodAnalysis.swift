import Foundation

/// Food analysis (ENGINE.md §4). Constants come from `EnergyModel.Food`.
public enum FoodAnalysis {
    private typealias F = EnergyModel.Food
    /// v1 label conversion: per-100 g ÷ 100, per-kg ÷ 1000, kJ additionally ÷ 4.184.
    public static func labelKcalPerGram(_ energyPerUnit: Double, _ unit: EnergyUnit) -> Double {
        energyPerUnit / (unit.rawValue.hasSuffix("/kg") ? 1000 : 100) / (unit.rawValue.hasPrefix("kJ") ? EnergyModel.Units.kjPerKcal : 1)
    }
    public static func moistureUsed(_ a: Analysis) -> Double { a.moisture ?? F.assumedDryMoisture }
    public static func nfe(_ a: Analysis) -> Double { max(0, 100 - moistureUsed(a) - a.protein - a.fat - a.fibre - a.ash) }
    /// ME4 in kcal/100 g as fed: FEDIAF/NRC 4-step for prepared foods, the fresh-food equation otherwise.
    public static func meKcalPer100g(_ a: Analysis) -> Double {
        let carb = nfe(a), m = moistureUsed(a)
        if a.kind == .fresh { return F.freshProtein * a.protein + F.freshFat * a.fat + F.freshNfe * carb }
        let ge = F.geProtein * a.protein + F.geFat * a.fat + F.geCarbohydrate * (carb + a.fibre)
        let fibreDM = a.fibre / (100 - m) * 100
        let digestibility = F.digestibilityIntercept - F.digestibilityFibreSlope * fibreDM
        return ge * digestibility / 100 - F.proteinCorrection * a.protein
    }
    public static func atwaterKcalPer100g(_ a: Analysis) -> Double {
        F.atwaterProtein * a.protein + F.atwaterFat * a.fat + F.atwaterNfe * nfe(a)
    }
    /// Per-food analysis; nil when the food has no analysis. Assumes a validated food.
    public static func analyse(_ food: Food) -> FoodAnalysisResult? {
        guard let a = food.analysis else { return nil }
        let m = moistureUsed(a), carb = nfe(a), me = meKcalPer100g(a), atwater = atwaterKcalPer100g(a)
        func dm(_ x: Double) -> Double { x / (100 - m) * 100 }
        let shares = [F.atwaterProtein * a.protein, F.atwaterFat * a.fat, F.atwaterNfe * carb]
        let total = shares[0] + shares[1] + shares[2]
        func share(_ x: Double) -> Double { total > 0 ? x / total * 100 : 0 }
        var warnings: [FoodWarningCode] = []
        if a.moisture == nil { warnings.append(.assumedMoisture) }
        if abs(atwater - me) / me > F.atwaterDisagreementFraction { warnings.append(.atwaterDisagreement) }
        if food.energySource != .analysis, let e = food.energyPerUnit,
           abs(labelKcalPerGram(e, food.energyUnit) * 100 - me) / me > F.labelMismatchFraction { warnings.append(.labelEnergyMismatch) }
        return FoodAnalysisResult(
            method: a.kind == .fresh ? .fediafFresh : .fediaf4Step, moisture: m, nfe: carb, meKcalPer100g: me, atwaterKcalPer100g: atwater,
            dryMatter: DryMatter(protein: dm(a.protein), fat: dm(a.fat), fibre: dm(a.fibre), ash: dm(a.ash), nfe: dm(carb)),
            proteinGPer1000kcal: a.protein / me * 1000, fatGPer1000kcal: a.fat / me * 1000, carbGPer100kcal: carb / me * 100,
            energySharePercent: EnergyShares(protein: share(shares[0]), fat: share(shares[1]), carbohydrate: share(shares[2])),
            warnings: warnings.sorted { $0.rawValue < $1.rawValue })
    }
}
