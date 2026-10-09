import Foundation

/// Nutrient checks (ENGINE.md §7).
public enum NutritionChecker {
    private typealias N = EnergyModel.Nutrition
    /// Grams eaten per food: fixed meals plus the rounded balance ration.
    public struct FoodIntake: Sendable {
        public let food: Food, grams: Double
        public init(food: Food, grams: Double) { self.food = food; self.grams = grams }
    }
    /// `kcal` is energy from foods, i.e. rounded daily kcal minus extras.
    public static func check(_ cat: Cat, estimate: EnergyEstimate, intake: [FoodIntake], kcal: Double) -> NutritionResult {
        guard estimate.status == .ok || estimate.status == .referenceOnly else { return .notApplicable }
        let used = intake.filter { $0.grams > 0 }
        let missing = Set(used.filter { $0.food.analysis == nil }.map(\.food.id)).sorted()
        if !missing.isEmpty || kcal <= 0 { return .incompleteData(missingFoodIds: missing) }
        // Carbohydrate share on the Atwater basis in numerator and denominator (D6).
        var proteinG = 0.0, carbAtwater = 0.0, atwater = 0.0
        for item in used {
            guard let a = item.food.analysis else { continue }
            proteinG += item.grams * a.protein / 100
            carbAtwater += item.grams * EnergyModel.Food.atwaterNfe * FoodAnalysis.nfe(a)
            atwater += item.grams * FoodAnalysis.atwaterKcalPer100g(a)
        }
        let stage = estimate.stage, growth = stage == .kitten || stage == .gestation || stage == .lactation
        let weight = estimate.weightUsedKg ?? cat.weightKg
        let minProteinPer1000 = stage == .kitten ? N.growthMinProteinPer1000
            : stage == .gestation || stage == .lactation ? N.reproductionMinProteinPer1000
            : max(N.adultMinProteinPer1000, N.proteinRequirementPer1000 / (kcal / pow(weight, EnergyModel.Mer.exponent)))
        let proteinPer1000 = proteinG / kcal * 1000, carbPercentME = atwater > 0 ? carbAtwater / atwater * 100 : 0
        let ckd = cat.profile.medical.contains(.ckd)
        var warnings: [NutritionWarningCode] = [], notes: [NutritionNoteCode] = []
        // Protein for a CKD cat is the veterinarian's decision: the minimum is shown, not checked.
        if proteinPer1000 < minProteinPer1000 && !ckd { warnings.append(.proteinBelowMinimum) }
        if estimate.equation == .weightLossAaha, let ibw = estimate.idealWeight, proteinG < N.lossProteinGPerKgIdeal * ibw.kg {
            warnings.append(.proteinBelow5gPerKgIbw)
        }
        if cat.profile.medical.contains(.diabetes) && carbPercentME > N.diabeticCarbPercentMe { warnings.append(.carbAboveDiabeticThreshold) }
        if growth && used.contains(where: { $0.food.lifeStageClaim != .growth && $0.food.lifeStageClaim != .all }) { warnings.append(.growthClaimMissing) }
        if ckd { notes.append(.ckdProteinVet) }
        return .ok(NutritionCheck(kcal: kcal, proteinG: proteinG, proteinPer1000: proteinPer1000, minProteinPer1000: minProteinPer1000,
                                  carbPercentME: carbPercentME, warnings: warnings.sorted { $0.rawValue < $1.rawValue }, notes: notes))
    }
}
