import Foundation

public enum WarningCode: String, Codable, CaseIterable, Sendable {
    case estimatedEnergy = "estimated-energy"
    case provisionalTarget = "provisional-target"
    case unknownCompleteness = "unknown-completeness"
    case complementaryBalanceFood = "complementary-balance-food"
    case extrasOverTenPercent = "extras-over-10-percent"
    case overBudget = "over-budget"
    public func message(locale: String = "en") -> String { Messages.message("warning.\(rawValue)", locale: locale) }
    public var message: String { message(locale: "en") }
}
public enum EstimateStatus: String, Codable, CaseIterable, Sendable {
    case ok, referenceOnly = "reference-only", needsInput = "needs-input", refer
}
public enum Stage: String, Codable, CaseIterable, Sendable {
    case neonate, kitten, adult, senior, gestation, lactation, endOfLife = "end-of-life"
}
public enum LifeStageLabel: String, Codable, CaseIterable, Sendable {
    case kitten, youngAdult = "young-adult", matureAdult = "mature-adult", senior
}
public enum EquationId: String, Codable, CaseIterable, Sendable {
    case adultFediaf = "adult-fediaf", weightLossAaha = "weight-loss-aaha", adultGain = "adult-gain", kittenNrc = "kitten-nrc"
    case kittenFediafBand = "kitten-fediaf-band", gestationFediaf = "gestation-fediaf", lactationFediaf = "lactation-fediaf"
}
public enum ReferCode: String, Codable, CaseIterable, Sendable {
    case neonate, endOfLife = "end-of-life", acuteMedical = "acute-medical", bcsLow = "bcs-low", mcsSevere = "mcs-severe"
    case rapidWeightChange = "rapid-weight-change", kittenNotGrowing = "kitten-not-growing"
    case verifiedIntakeBelowFloor = "verified-intake-below-floor"
}
public enum InputCode: String, Codable, CaseIterable, Sendable {
    case age, neutered, bcs, mcs, litterSize = "litter-size", lactationWeek = "lactation-week"
}
public enum NoteCode: String, Codable, CaseIterable, Sendable {
    case lossNotIndicated = "loss-not-indicated", gainNotIndicated = "gain-not-indicated", seniorWiderRange = "senior-wider-range"
    case overweightConsiderLoss = "overweight-consider-loss", clampedHigh = "clamped-high", recentlyNeutered = "recently-neutered"
    case medicalVetPlan = "medical-vet-plan", diabetesLowCarbInfo = "diabetes-low-carb-info"
    case kittenAdultWeightUnknown = "kitten-adult-weight-unknown", kittenWeighWeekly = "kitten-weigh-weekly"
    case kittenTransition = "kitten-transition", growthComplete = "growth-complete"
    case preBreedingWeightAssumed = "pre-breeding-weight-assumed", freeChoiceRecommended = "free-choice-recommended"
    case reproductionVet = "reproduction-vet", weaningTransition = "weaning-transition"
}
public enum IdealWeightSource: String, Codable, CaseIterable, Sendable { case veterinarian, estimate, bcsEstimate = "bcs-estimate", current }
public enum FoodWarningCode: String, Codable, CaseIterable, Sendable {
    case assumedMoisture = "assumed-moisture", atwaterDisagreement = "atwater-disagreement", labelEnergyMismatch = "label-energy-mismatch"
}
public enum FoodAnalysisMethod: String, Codable, CaseIterable, Sendable { case fediaf4Step = "fediaf-4-step", fediafFresh = "fediaf-fresh" }
public enum SuggestionAction: String, Codable, CaseIterable, Sendable {
    case switchToMaintenance = "switch-to-maintenance", increase, decrease, hold, none, refer
}
public enum SuggestionReason: String, Codable, CaseIterable, Sendable {
    case idealWeightReached = "ideal-weight-reached", lossTooFast = "loss-too-fast", onTrack = "on-track"
    case slowRecheckTwoWeeks = "slow-recheck-2-weeks", plateau, atFloor = "at-floor", gaining, losing, stable
    case idealConditionReached = "ideal-condition-reached", gainTooFast = "gain-too-fast", notGaining = "not-gaining"
}
public enum NutritionWarningCode: String, Codable, CaseIterable, Sendable {
    case proteinBelowMinimum = "protein-below-minimum", proteinBelow5gPerKgIbw = "protein-below-5g-per-kg-ibw"
    case carbAboveDiabeticThreshold = "carb-above-diabetic-threshold", growthClaimMissing = "growth-claim-missing"
}
public enum NutritionNoteCode: String, Codable, CaseIterable, Sendable { case ckdProteinVet = "ckd-protein-vet" }

public struct IdealWeight: Encodable, Equatable, Sendable {
    public let kg: Double, lowKg: Double, highKg: Double
    public let source: IdealWeightSource
}
public struct ReferenceBand: Encodable, Equatable, Sendable { public let lowKcal: Double, highKcal: Double }
public struct Comparison: Encodable, Equatable, Sendable {
    public let targetToStartRatio: Double
    public let belowRange: Bool, aboveRange: Bool, differsOver30Percent: Bool, belowFloor: Bool
}
public struct EnergyEstimate: Encodable, Equatable, Sendable {
    public let status: EstimateStatus
    public let stage: Stage?
    public let lifeStageLabel: LifeStageLabel?
    public let ageMonths: Double?
    public let rerKcal: Double
    public let idealWeight: IdealWeight?
    public let equation: EquationId?
    public let coefficient: Double?
    public let weightUsedKg: Double?
    public let startKcal: Double?, lowKcal: Double?, highKcal: Double?
    public let floorKcal: Double?
    public let referenceBand: ReferenceBand?
    public let reasons: [ReferCode]
    public let missing: [InputCode]
    public let notes: [NoteCode]
    public let comparison: Comparison?
}
public struct Suggestion: Encodable, Equatable, Sendable {
    public let action: SuggestionAction
    public let reason: SuggestionReason
    public let suggestedKcal: Double?
}
public struct Trend: Encodable, Equatable, Sendable {
    public let entries: Int
    public let latestKg: Double?
    public let ratePercentPerWeek: Double?
    public let change28dPercent: Double?
    public let suggestion: Suggestion?
    public let nextWeighInDays: Int
}
public struct NutritionCheck: Encodable, Equatable, Sendable {
    public let kcal: Double, proteinG: Double, proteinPer1000: Double, minProteinPer1000: Double, carbPercentME: Double
    public let warnings: [NutritionWarningCode]
    public let notes: [NutritionNoteCode]
}
public enum NutritionResult: Encodable, Equatable, Sendable {
    case ok(NutritionCheck)
    case incompleteData(missingFoodIds: [String])
    case notApplicable
    private enum CodingKeys: String, CodingKey {
        case status, kcal, proteinG, proteinPer1000, minProteinPer1000, carbPercentME, warnings, notes, missingFoodIds
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ok(let n):
            try c.encode("ok", forKey: .status); try c.encode(n.kcal, forKey: .kcal); try c.encode(n.proteinG, forKey: .proteinG)
            try c.encode(n.proteinPer1000, forKey: .proteinPer1000); try c.encode(n.minProteinPer1000, forKey: .minProteinPer1000)
            try c.encode(n.carbPercentME, forKey: .carbPercentME); try c.encode(n.warnings, forKey: .warnings)
            try c.encode(n.notes, forKey: .notes)
        case .incompleteData(let ids):
            try c.encode("incomplete-data", forKey: .status); try c.encode(ids, forKey: .missingFoodIds)
        case .notApplicable:
            try c.encode("not-applicable", forKey: .status)
        }
    }
}

public struct DryMatter: Encodable, Equatable, Sendable { public let protein: Double, fat: Double, fibre: Double, ash: Double, nfe: Double }
public struct EnergyShares: Encodable, Equatable, Sendable { public let protein: Double, fat: Double, carbohydrate: Double }
public struct FoodAnalysisResult: Encodable, Equatable, Sendable {
    public let method: FoodAnalysisMethod
    public let moisture: Double, nfe: Double, meKcalPer100g: Double, atwaterKcalPer100g: Double
    public let dryMatter: DryMatter
    public let proteinGPer1000kcal: Double, fatGPer1000kcal: Double, carbGPer100kcal: Double
    public let energySharePercent: EnergyShares
    public let warnings: [FoodWarningCode]
}
public struct FoodResult: Encodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let kcalPerGram: Double
    public let analysis: FoodAnalysisResult?
}

public struct ActivityPortion: Encodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let sharePercent: Double
    public let exactGrams: Double
    public let roundedGrams: Int
}
public struct CatResult: Encodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let fixedGrams: Double
    public let fixedKcal: Double
    public let extraKcal: Double
    public let balanceFoodId: String
    public let balanceKcal: Double
    public let balanceGramsExact: Double
    public let balanceGramsRounded: Int
    public let overBudgetKcal: Double
    public let roundedDailyKcal: Double
    public let rerKcal: Double
    public let warnings: [WarningCode]
    public let activities: [ActivityPortion]
    public let estimate: EnergyEstimate
    public let trend: Trend
    public let nutrition: NutritionResult
}
public struct BalanceByFood: Encodable, Equatable, Sendable {
    public let foodId: String
    public let gramsExact: Double
    public let gramsRounded: Int
}
public struct Totals: Encodable, Equatable, Sendable {
    public let fixedGrams: Double
    public let fixedKcal: Double
    public let targetKcal: Double
    public let balanceGramsExact: Double
    public let balanceGramsRounded: Int
    public let roundedDailyKcal: Double
    public let balanceByFood: [BalanceByFood]
}
public struct PlanResult: Encodable, Equatable, Sendable {
    public let cats: [CatResult]
    public let foods: [FoodResult]
    public let totals: Totals
}
