import Foundation

public struct PlanError: LocalizedError, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
/// Validates plans with the same rules and bounds as the TypeScript `parsePlan` (ENGINE.md §1).
public enum PlanValidator {
    /// The JS `String.prototype.trim()` set: WhiteSpace plus LineTerminator (not U+200B).
    private static func isJSWhitespace(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x09...0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF: return true
        default: return false
        }
    }
    /// Control characters and bidirectional overrides are rejected; the multi-line note may keep tab and line feed.
    private static func isForbidden(_ s: Unicode.Scalar, multiline: Bool) -> Bool {
        if multiline && (s.value == 0x09 || s.value == 0x0A) { return false }
        switch s.value {
        case 0x00...0x1F, 0x7F, 0x202A...0x202E, 0x2066...0x2069: return true
        default: return false
        }
    }
    private static func text(_ value: String, _ path: String, max: Int = 120, allowEmpty: Bool = false, multiline: Bool = false) throws {
        let blank = value.unicodeScalars.allSatisfy(isJSWhitespace)
        guard (allowEmpty || !blank), value.utf16.count <= max else {
            throw PlanError("\(path): expected \(allowEmpty ? 0 : 1)–\(max) characters")
        }
        guard !value.unicodeScalars.contains(where: { isForbidden($0, multiline: multiline) }) else {
            throw PlanError("\(path): control and direction-override characters are not allowed")
        }
    }
    private static func id(_ value: String, _ path: String) throws {
        try text(value, path, max: 64)
        guard value.range(of: "^[A-Za-z0-9][A-Za-z0-9_-]*\\z", options: .regularExpression) != nil else {
            throw PlanError("\(path): use letters, numbers, hyphens, or underscores")
        }
    }
    private static func number(_ value: Double, _ path: String, _ range: ClosedRange<Double>) throws {
        guard value.isFinite, range.contains(value) else { throw PlanError("\(path): expected a finite number between \(range.lowerBound) and \(range.upperBound)") }
    }
    private static func integer(_ value: Int, _ path: String, _ range: ClosedRange<Int>) throws {
        guard range.contains(value) else { throw PlanError("\(path): expected a whole number between \(range.lowerBound) and \(range.upperBound)") }
    }
    private static func count(_ value: Int, _ path: String, _ range: ClosedRange<Int>) throws {
        guard range.contains(value) else { throw PlanError("\(path): expected \(range.lowerBound)–\(range.upperBound) entries") }
    }
    private static func date(_ value: String, _ path: String) throws {
        guard Dates.isISODate(value) else { throw PlanError("\(path): expected a valid date in the form YYYY-MM-DD") }
    }
    private static func unique(_ ids: [String], _ path: String) throws {
        guard Set(ids).count == ids.count else { throw PlanError("\(path): IDs must be unique within this list") }
    }
    private static func percent(_ value: Double, _ path: String) throws { try number(value, path, 0...100) }
    private static func weight(_ value: Double, _ path: String) throws { try number(value, path, 0.1...40) }
    private static func checkDensity(_ kcalPerGram: Double, _ name: String) throws {
        guard kcalPerGram >= 0.01 && kcalPerGram <= 10 else { throw PlanError("food \(name): energy must be between 0.01 and 10 kcal/g; check the unit") }
    }
    private static func analysis(_ a: Analysis, _ path: String, type: FoodType) throws {
        try percent(a.protein, "\(path).protein"); try percent(a.fat, "\(path).fat"); try percent(a.fibre, "\(path).fibre")
        try percent(a.ash, "\(path).ash")
        if let moisture = a.moisture { try percent(moisture, "\(path).moisture") }
        else if type != .dry { throw PlanError("\(path).moisture: moisture may only be omitted for dry food") }
        let moisture = FoodAnalysis.moistureUsed(a)
        guard moisture < 100 else { throw PlanError("\(path).moisture: moisture must be below 100%") }
        guard moisture + a.protein + a.fat + a.fibre + a.ash <= 100 + 1e-9 else {
            throw PlanError("\(path): constituents must not add up to more than 100%")
        }
    }
    private static func food(_ f: Food, _ path: String) throws {
        try id(f.id, "\(path).id"); try text(f.name, "\(path).name")
        if let energy = f.energyPerUnit { try number(energy, "\(path).energyPerUnit", 0.001...50000) }
        if let a = f.analysis { try analysis(a, "\(path).analysis", type: f.type) }
        try text(f.note, "\(path).note", max: 1000, allowEmpty: true, multiline: true)
        if f.energySource == .analysis && f.analysis == nil { throw PlanError("\(path).analysis: required when energy comes from the analysis") }
        if f.energySource != .analysis && f.energyPerUnit == nil { throw PlanError("\(path).energyPerUnit: required unless energy comes from the analysis") }
    }
    private static func reproduction(_ r: Reproduction, _ path: String) throws {
        if let n = r.litterSize { try integer(n, "\(path).litterSize", 1...12) }
        if let n = r.lactationWeek { try integer(n, "\(path).lactationWeek", 1...12) }
        if let w = r.preBreedingWeightKg { try weight(w, "\(path).preBreedingWeightKg") }
    }
    private static func profile(_ p: Profile, _ path: String) throws {
        try count(p.medical.count, "\(path).medical", 0...MedicalFlag.allCases.count)
        guard Set(p.medical).count == p.medical.count else { throw PlanError("\(path).medical: flags must be unique") }
        if let d = p.birthDate { try date(d, "\(path).birthDate") }
        if let y = p.approxAgeYears { try number(y, "\(path).approxAgeYears", 0...30) }
        if let d = p.neuteredDate { try date(d, "\(path).neuteredDate") }
        if let b = p.bcs { try integer(b, "\(path).bcs", 1...9) }
        if let w = p.idealWeightKg { try weight(w, "\(path).idealWeightKg") }
        else if p.idealWeightSource != nil { throw PlanError("\(path).idealWeightSource: must be null when there is no ideal weight") }
        if let w = p.expectedAdultWeightKg { try weight(w, "\(path).expectedAdultWeightKg") }
        try reproduction(p.reproduction, "\(path).reproduction")
        if let k = p.verifiedIntakeKcal { try number(k, "\(path).verifiedIntakeKcal", 1...3000) }
    }
    private static func cat(_ c: Cat, _ path: String) throws {
        try id(c.id, "\(path).id"); try text(c.name, "\(path).name"); try weight(c.weightKg, "\(path).weightKg")
        try number(c.targetKcal, "\(path).targetKcal", 1...3000); try number(c.extraKcal, "\(path).extraKcal", 0...3000)
        try id(c.balanceFoodId, "\(path).balanceFoodId")
        try count(c.meals.count, "\(path).meals", 0...24)
        for (i, m) in c.meals.enumerated() {
            try id(m.id, "\(path).meals[\(i)].id"); try text(m.label, "\(path).meals[\(i)].label")
            try id(m.foodId, "\(path).meals[\(i)].foodId"); try number(m.grams, "\(path).meals[\(i)].grams", 0...1000)
        }
        try unique(c.meals.map(\.id), "\(path).meals")
        try count(c.weightLog.count, "\(path).weightLog", 0...1000)
        for (i, e) in c.weightLog.enumerated() {
            let p = "\(path).weightLog[\(i)]"
            try id(e.id, "\(p).id"); try date(e.date, "\(p).date"); try weight(e.weightKg, "\(p).weightKg")
            if let b = e.bcs { try integer(b, "\(p).bcs", 1...9) }
        }
        try unique(c.weightLog.map(\.id), "\(path).weightLog")
        try profile(c.profile, "\(path).profile")
    }
    public static func validate(_ plan: Plan) throws {
        guard plan.schemaVersion == 2 else { throw PlanError("schemaVersion: only versions 1 and 2 are supported") }
        try text(plan.name, "name")
        try count(plan.foods.count, "foods", 1...100)
        for (i, f) in plan.foods.enumerated() { try food(f, "foods[\(i)]") }
        try unique(plan.foods.map(\.id), "foods")
        try count(plan.cats.count, "cats", 1...50)
        for (i, c) in plan.cats.enumerated() { try cat(c, "cats[\(i)]") }
        try unique(plan.cats.map(\.id), "cats")
        try count(plan.activities.count, "activities", 1...12)
        for (i, a) in plan.activities.enumerated() {
            try id(a.id, "activities[\(i)].id"); try text(a.label, "activities[\(i)].label")
            try number(a.sharePercent, "activities[\(i)].sharePercent", 0...100)
        }
        try unique(plan.activities.map(\.id), "activities")
        guard abs(plan.activities.reduce(0) { $0 + $1.sharePercent } - 100) <= 1e-6 else { throw PlanError("activities: shares must add up to 100%") }
        let foods = Dictionary(plan.foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for f in plan.foods {
            if let e = f.energyPerUnit { try checkDensity(FoodAnalysis.labelKcalPerGram(e, f.energyUnit), f.name) }
            if let a = f.analysis { try checkDensity(FoodAnalysis.meKcalPer100g(a) / 100, f.name) }
        }
        for c in plan.cats {
            guard foods[c.balanceFoodId] != nil else { throw PlanError("cat \(c.name): balance food must reference a food in the library") }
            for m in c.meals where foods[m.foodId] == nil { throw PlanError("meal \(m.label): meal must reference a food in the library") }
        }
    }
    /// The v1 type rules that v2 dropped: the dry food must be dry, meals must be wet, no analysis energy source.
    static func validateV1Types(_ plan: PlanV1) throws {
        let foods = Dictionary(plan.foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for f in plan.foods where f.energySource == .analysis { throw PlanError("food \(f.name): energySource analysis needs schema version 2") }
        for c in plan.cats {
            guard foods[c.dryFoodId]?.type == .dry else { throw PlanError("cat \(c.name): dry food must reference a dry food in the library") }
            for m in c.meals where foods[m.foodId]?.type != .wet { throw PlanError("meal \(m.label): meal must reference a wet food in the library") }
        }
    }
}
