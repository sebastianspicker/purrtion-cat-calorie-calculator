import Foundation

/// Native implementation of the same documented contract as the TypeScript engine (docs/ENGINE.md).
/// Shared golden fixtures protect the two implementations against numerical drift.
public enum CalorieCalculator {
    public static let kilojoulesPerKilocalorie = EnergyModel.Units.kjPerKcal
    /// All internal arithmetic uses kcal and grams, with no intermediate rounding. Analysis-sourced energy uses ME4 (ENGINE.md §4).
    public static func kcalPerGram(_ food: Food) throws -> Double {
        if food.energySource == .analysis, let analysis = food.analysis { return FoodAnalysis.meKcalPer100g(analysis) / 100 }
        guard let energy = food.energyPerUnit else { throw PlanError("Food energy is missing") }
        return FoodAnalysis.labelKcalPerGram(energy, food.energyUnit)
    }
    public static func energyInUnit(_ food: Food, unit: EnergyUnit) throws -> Double {
        try kcalPerGram(food) * (unit.rawValue.hasSuffix("/kg") ? 1000 : 100) * (unit.rawValue.hasPrefix("kJ") ? kilojoulesPerKilocalorie : 1)
    }
    public static func rer(_ weightKg: Double) throws -> Double { try Estimator.rer(weightKg) }
    public static func allocateRounded(_ totalGrams: Double, activities: [Activity]) throws -> [Int] {
        guard totalGrams.isFinite, totalGrams >= 0, totalGrams <= 1_000_000, !activities.isEmpty,
              activities.allSatisfy({ $0.sharePercent.isFinite && (0...100).contains($0.sharePercent) }),
              abs(activities.reduce(0) { $0 + $1.sharePercent } - 100) <= 1e-6 else {
            throw PlanError("A nonnegative amount and activity shares totaling 100% are required")
        }
        let total = Int(totalGrams.rounded(.toNearestOrAwayFromZero))
        let raw = activities.map { Double(total) * $0.sharePercent / 100 }
        var portions = raw.map { Int(floor($0)) }
        let remaining = total - portions.reduce(0, +)
        let order = raw.indices.sorted { a, b in
            let first = raw[a] - floor(raw[a]), second = raw[b] - floor(raw[b])
            return first == second ? a < b : first > second
        }
        if remaining > 0 { for n in 0..<remaining { portions[order[n % order.count]] += 1 } }
        return portions
    }
    /// Validates the plan and calculates every cat. `asOf` (YYYY-MM-DD) keeps the core pure and deterministic. Never changes `targetKcal`.
    public static func calculate(_ plan: Plan, asOf: String) throws -> PlanResult {
        guard Dates.isISODate(asOf) else { throw PlanError("asOf: expected a valid date in the form YYYY-MM-DD") }
        try PlanValidator.validate(plan)
        let foods = Dictionary(uniqueKeysWithValues: plan.foods.map { ($0.id, $0) })
        let cats = try plan.cats.map { try calculateCat($0, plan: plan, foods: foods, asOf: asOf) }
        var balanceByFood: [BalanceByFood] = []
        for c in cats {
            if let index = balanceByFood.firstIndex(where: { $0.foodId == c.balanceFoodId }) {
                let e = balanceByFood[index]
                balanceByFood[index] = BalanceByFood(foodId: e.foodId, gramsExact: e.gramsExact + c.balanceGramsExact, gramsRounded: e.gramsRounded + c.balanceGramsRounded)
            } else { balanceByFood.append(BalanceByFood(foodId: c.balanceFoodId, gramsExact: c.balanceGramsExact, gramsRounded: c.balanceGramsRounded)) }
        }
        return PlanResult(cats: cats, foods: try plan.foods.map { FoodResult(id: $0.id, kcalPerGram: try kcalPerGram($0), analysis: FoodAnalysis.analyse($0)) },
            totals: Totals(
                fixedGrams: cats.reduce(0) { $0 + $1.fixedGrams }, fixedKcal: cats.reduce(0) { $0 + $1.fixedKcal },
                targetKcal: plan.cats.reduce(0) { $0 + $1.targetKcal }, balanceGramsExact: cats.reduce(0) { $0 + $1.balanceGramsExact },
                // Sum the containers that people actually prepare. Do not round the exact household sum instead.
                balanceGramsRounded: cats.reduce(0) { $0 + $1.balanceGramsRounded },
                roundedDailyKcal: cats.reduce(0) { $0 + $1.roundedDailyKcal }, balanceByFood: balanceByFood))
    }
    private static func calculateCat(_ cat: Cat, plan: Plan, foods: [String: Food], asOf: String) throws -> CatResult {
        let balance = foods[cat.balanceFoodId]! // Public boundary validates all references before lookup.
        var warnings = Set<WarningCode>()
        var intake: [NutritionChecker.FoodIntake] = []
        var fixedGrams = 0.0, fixedKcal = 0.0, complementaryKcal = cat.extraKcal
        func inspect(_ food: Food, kcal: Double) {
            guard kcal > 0 else { return }
            // Energy computed from an analysis is an estimate too (SCIENCE.md §10.2).
            if food.energySource == .estimate || food.energySource == .analysis { warnings.insert(.estimatedEnergy) }
            if food.completeness == .unknown { warnings.insert(.unknownCompleteness) }
            if food.completeness == .complementary { complementaryKcal += kcal }
        }
        for meal in cat.meals {
            let food = foods[meal.foodId]!
            let calories = meal.grams * (try kcalPerGram(food))
            fixedGrams += meal.grams; fixedKcal += calories; inspect(food, kcal: calories)
            intake.append(.init(food: food, grams: meal.grams))
        }
        let balanceRate = try kcalPerGram(balance)
        let remaining = cat.targetKcal - fixedKcal - cat.extraKcal
        let balanceKcal = max(0, remaining), exact = balanceKcal / balanceRate
        let rounded = Int(exact.rounded(.toNearestOrAwayFromZero))
        inspect(balance, kcal: Double(rounded) * balanceRate)
        intake.append(.init(food: balance, grams: Double(rounded)))
        if rounded > 0 && balance.completeness == .complementary { warnings.insert(.complementaryBalanceFood) }
        if cat.targetSource == .provisional { warnings.insert(.provisionalTarget) }
        if complementaryKcal > cat.targetKcal * EnergyModel.Allocation.extrasMaxFraction + 1e-8 { warnings.insert(.extrasOverTenPercent) }
        if remaining < -1e-8 { warnings.insert(.overBudget) }
        let portions = try allocateRounded(exact, activities: plan.activities)
        let roundedDailyKcal = fixedKcal + cat.extraKcal + Double(rounded) * balanceRate
        let series = try TrendAnalysis.weightSeries(cat, asOf: asOf)
        let estimate = try Estimator.estimate(cat, asOf: asOf, trendStops: TrendAnalysis.stops(cat, series: series, stage: Estimator.stageOf(cat, asOf: asOf)))
        return CatResult(id: cat.id, fixedGrams: fixedGrams, fixedKcal: fixedKcal, extraKcal: cat.extraKcal, balanceFoodId: balance.id,
            balanceKcal: balanceKcal, balanceGramsExact: exact, balanceGramsRounded: rounded,
            overBudgetKcal: max(0, -remaining), roundedDailyKcal: roundedDailyKcal,
            rerKcal: try rer(cat.weightKg), warnings: warnings.sorted { $0.rawValue < $1.rawValue },
            activities: plan.activities.enumerated().map { index, a in
                ActivityPortion(id: a.id, label: a.label, sharePercent: a.sharePercent,
                                exactGrams: exact * a.sharePercent / 100, roundedGrams: portions[index])
            },
            estimate: estimate, trend: try TrendAnalysis.trend(cat, asOf: asOf, estimate: estimate, series: series),
            nutrition: NutritionChecker.check(cat, estimate: estimate, intake: intake, kcal: roundedDailyKcal - cat.extraKcal))
    }
}
