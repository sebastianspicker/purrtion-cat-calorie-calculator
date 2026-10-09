import Foundation

public enum Migration {
    /// Migrates a v1 plan to v2 (ENGINE.md §9). Allocation results are unchanged.
    public static func migrate(_ plan: PlanV1) -> Plan {
        Plan(schemaVersion: 2, name: plan.name,
             foods: plan.foods.map { Food(id: $0.id, name: $0.name, type: $0.type, energyPerUnit: $0.energyPerUnit, energyUnit: $0.energyUnit,
                                          energySource: $0.energySource, completeness: $0.completeness, lifeStageClaim: .unknown, analysis: nil, note: $0.note) },
             cats: plan.cats.map { Cat(id: $0.id, name: $0.name, weightKg: $0.weightKg, goal: $0.goal, targetKcal: $0.targetKcal,
                                       targetSource: $0.targetSource, extraKcal: $0.extraKcal, balanceFoodId: $0.dryFoodId,
                                       meals: $0.meals, profile: Profile(), weightLog: [], icon: nil) },
             activities: plan.activities)
    }
}
