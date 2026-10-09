import SwiftUI
import PurrtionCore

/// A new plan-unique id such as `cat-1A2B…`.
func newId(_ prefix: String) -> String { "\(prefix)-\(UUID().uuidString)" }

/// Whole kcal for a target, inside the validator's 1–3000 range.
func targetKcal(from value: Double) -> Double { min(3000, max(1, value.rounded(.toNearestOrAwayFromZero))) }

/// A binding to the element with `id`, looked up on every access so a row that has just been removed neither crashes nor writes back.
func elementBinding<Element: Identifiable & Sendable>(_ list: Binding<[Element]>, id: Element.ID, fallback: Element) -> Binding<Element>
    where Element.ID: Equatable & Sendable {
    let source = list
    return Binding(get: { source.wrappedValue.first { $0.id == id } ?? fallback },
                   set: { new in if let index = source.wrappedValue.firstIndex(where: { $0.id == id }) { source.wrappedValue[index] = new } })
}

extension Plan {
    func food(_ id: String) -> Food? { foods.first { $0.id == id } }
    func foodName(_ id: String) -> String { food(id)?.name ?? id }
    func cat(_ id: String) -> Cat? { cats.first { $0.id == id } }
    /// Replaces the cat with the same id, or appends it.
    func with(_ cat: Cat) -> Plan {
        var plan = self
        if let index = plan.cats.firstIndex(where: { $0.id == cat.id }) { plan.cats[index] = cat } else { plan.cats.append(cat) }
        return plan
    }
}

extension Food {
    /// Effective energy in the food's own unit; nil when the food cannot be evaluated (e.g. an incomplete analysis).
    var displayEnergy: Double? {
        guard let value = try? CalorieCalculator.energyInUnit(self, unit: energyUnit), value.isFinite, value > 0 else { return nil }
        return value
    }
}

typealias IdealWeightSourceChoice = ProfileIdealWeightSource

/// Access to `Profile.idealWeightSource` (veterinarian | estimate | nil, ENGINE.md §1 D3).
/// A stored ideal weight without a source counts as the veterinarian's, as in the decoder.
enum ProfileAdapter {
    static let hasIdealWeightSource = true
    static func idealWeightSource(_ profile: Profile) -> IdealWeightSourceChoice? {
        profile.idealWeightKg == nil ? nil : profile.idealWeightSource ?? .veterinarian
    }
    static func setIdealWeightSource(_ profile: inout Profile, _ source: IdealWeightSourceChoice?) {
        profile.idealWeightSource = source
    }
}

extension Cat {
    /// Adds a weigh-in (ENGINE.md "Current weight"): when its date is on or after the date of every other entry,
    /// it also sets the current weight and, if it has a BCS, the profile BCS. The engine uses `weightKg` as the current weight.
    /// An existing entry on the same date is replaced rather than duplicated.
    mutating func addWeighIn(date: String, weightKg weight: Double, bcs: Int?) {
        weightLog.removeAll { $0.date == date }
        let isNewest = weightLog.allSatisfy { $0.date <= date }
        weightLog.append(WeightEntry(id: newId("weight"), date: date, weightKg: weight, bcs: bcs))
        if isNewest {
            weightKg = weight
            if let bcs { profile.bcs = bcs }
        }
    }
}
