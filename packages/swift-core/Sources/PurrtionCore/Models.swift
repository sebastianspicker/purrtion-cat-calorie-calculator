import Foundation

public enum EnergyUnit: String, Codable, CaseIterable, Sendable {
    case kcalPer100g = "kcal/100g", kJPer100g = "kJ/100g", kcalPerKg = "kcal/kg", kJPerKg = "kJ/kg"
}
public enum FoodType: String, Codable, CaseIterable, Sendable { case wet, dry }
public enum EnergySource: String, Codable, CaseIterable, Sendable { case label, estimate, analysis }
public enum Completeness: String, Codable, CaseIterable, Sendable { case complete, complementary, unknown }
public enum LifeStageClaim: String, Codable, CaseIterable, Sendable { case adult, growth, all, unknown }
public enum AnalysisKind: String, Codable, CaseIterable, Sendable { case prepared, fresh }
public enum Goal: String, Codable, CaseIterable, Sendable { case loss, maintain, gain }
public enum TargetSource: String, Codable, CaseIterable, Sendable { case provisional, owner, veterinarian }
public enum Sex: String, Codable, CaseIterable, Sendable { case female, male, unknown }
public enum Neutered: String, Codable, CaseIterable, Sendable { case yes, no, unknown }
public enum Lifestyle: String, Codable, CaseIterable, Sendable { case sedentary, typical, active }
public enum MuscleCondition: String, Codable, CaseIterable, Sendable { case normal, mild, moderate, severe }
public enum ReproductionStatus: String, Codable, CaseIterable, Sendable { case none, gestation, lactation }
/// Where a stored ideal weight comes from (ENGINE.md §1, D3).
public enum ProfileIdealWeightSource: String, Codable, CaseIterable, Sendable { case veterinarian, estimate }
public enum MedicalFlag: String, Codable, CaseIterable, Sendable {
    case ckd, diabetes, hyperthyroid, gi, pancreatitis, urinary, cancer, other
    case prescriptionDiet = "prescription-diet"
    case hepaticLipidosis = "hepatic-lipidosis", hospitalised
    case notEating = "not-eating", clinicalSigns = "clinical-signs"
    /// Acute flags give `refer` status; all others are chronic and give `reference-only`.
    public var isAcute: Bool { [.hepaticLipidosis, .hospitalised, .notEating, .clinicalSigns].contains(self) }
}

extension KeyedEncodingContainer {
    /// Writes an explicit `null` for nil, so exports have the same shape as the TypeScript exporter.
    mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
    }
}

/// Percent as fed (the EU "analytical constituents" declaration). ENGINE.md §1.
public struct Analysis: Codable, Equatable, Sendable {
    public var protein: Double, fat: Double, fibre: Double, ash: Double
    /// Null only for dry foods; the engine then assumes `EnergyModel.Food.assumedDryMoisture`.
    public var moisture: Double?
    public var kind: AnalysisKind
    public init(protein: Double, fat: Double, fibre: Double, ash: Double, moisture: Double?, kind: AnalysisKind = .prepared) {
        self.protein = protein; self.fat = fat; self.fibre = fibre; self.ash = ash; self.moisture = moisture; self.kind = kind
    }
    private enum CodingKeys: String, CodingKey { case protein, fat, fibre, ash, moisture, kind }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        protein = try c.decode(Double.self, forKey: .protein); fat = try c.decode(Double.self, forKey: .fat)
        fibre = try c.decode(Double.self, forKey: .fibre); ash = try c.decode(Double.self, forKey: .ash)
        moisture = try c.decodeIfPresent(Double.self, forKey: .moisture); kind = try c.decode(AnalysisKind.self, forKey: .kind)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(protein, forKey: .protein); try c.encode(fat, forKey: .fat); try c.encode(fibre, forKey: .fibre)
        try c.encode(ash, forKey: .ash); try c.encodeNullable(moisture, forKey: .moisture); try c.encode(kind, forKey: .kind)
    }
}
public struct Food: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var type: FoodType
    /// Nil only when `energySource` is `.analysis`.
    public var energyPerUnit: Double?
    public var energyUnit: EnergyUnit
    public var energySource: EnergySource
    public var completeness: Completeness
    public var lifeStageClaim: LifeStageClaim
    public var analysis: Analysis?
    public var note: String
    public init(id: String, name: String, type: FoodType, energyPerUnit: Double?, energyUnit: EnergyUnit, energySource: EnergySource,
                completeness: Completeness, lifeStageClaim: LifeStageClaim = .unknown, analysis: Analysis? = nil, note: String = "") {
        self.id = id; self.name = name; self.type = type; self.energyPerUnit = energyPerUnit; self.energyUnit = energyUnit
        self.energySource = energySource; self.completeness = completeness; self.lifeStageClaim = lifeStageClaim
        self.analysis = analysis; self.note = note
    }
    private enum CodingKeys: String, CodingKey {
        case id, name, type, energyPerUnit, energyUnit, energySource, completeness, lifeStageClaim, analysis, note
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        type = try c.decode(FoodType.self, forKey: .type)
        energyPerUnit = try c.decodeIfPresent(Double.self, forKey: .energyPerUnit)
        energyUnit = try c.decode(EnergyUnit.self, forKey: .energyUnit); energySource = try c.decode(EnergySource.self, forKey: .energySource)
        completeness = try c.decode(Completeness.self, forKey: .completeness)
        lifeStageClaim = try c.decode(LifeStageClaim.self, forKey: .lifeStageClaim)
        analysis = try c.decodeIfPresent(Analysis.self, forKey: .analysis); note = try c.decode(String.self, forKey: .note)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(type, forKey: .type)
        try c.encodeNullable(energyPerUnit, forKey: .energyPerUnit); try c.encode(energyUnit, forKey: .energyUnit)
        try c.encode(energySource, forKey: .energySource); try c.encode(completeness, forKey: .completeness)
        try c.encode(lifeStageClaim, forKey: .lifeStageClaim); try c.encodeNullable(analysis, forKey: .analysis)
        try c.encode(note, forKey: .note)
    }
}
public struct Meal: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var foodId: String
    public var grams: Double
    public init(id: String, label: String, foodId: String, grams: Double) {
        self.id = id; self.label = label; self.foodId = foodId; self.grams = grams
    }
}
public struct Reproduction: Codable, Equatable, Sendable {
    public var status: ReproductionStatus
    public var litterSize: Int?
    public var lactationWeek: Int?
    public var preBreedingWeightKg: Double?
    public init(status: ReproductionStatus = .none, litterSize: Int? = nil, lactationWeek: Int? = nil, preBreedingWeightKg: Double? = nil) {
        self.status = status; self.litterSize = litterSize; self.lactationWeek = lactationWeek; self.preBreedingWeightKg = preBreedingWeightKg
    }
    private enum CodingKeys: String, CodingKey { case status, litterSize, lactationWeek, preBreedingWeightKg }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(ReproductionStatus.self, forKey: .status)
        litterSize = try c.decodeIfPresent(Int.self, forKey: .litterSize); lactationWeek = try c.decodeIfPresent(Int.self, forKey: .lactationWeek)
        preBreedingWeightKg = try c.decodeIfPresent(Double.self, forKey: .preBreedingWeightKg)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(status, forKey: .status); try c.encodeNullable(litterSize, forKey: .litterSize)
        try c.encodeNullable(lactationWeek, forKey: .lactationWeek); try c.encodeNullable(preBreedingWeightKg, forKey: .preBreedingWeightKg)
    }
}
public struct Profile: Codable, Equatable, Sendable {
    public var birthDate: String?
    public var approxAgeYears: Double?
    public var sex: Sex
    public var neutered: Neutered
    public var neuteredDate: String?
    public var lifestyle: Lifestyle?
    public var bcs: Int?
    public var mcs: MuscleCondition?
    public var idealWeightKg: Double?
    /// Nil if and only if `idealWeightKg` is nil; a stored weight without a source counts as the veterinarian's.
    public var idealWeightSource: ProfileIdealWeightSource?
    public var expectedAdultWeightKg: Double?
    public var reproduction: Reproduction
    public var medical: [MedicalFlag]
    public var endOfLife: Bool
    public var verifiedIntakeKcal: Double?
    /// The all-null/unknown profile used for migrated and newly created cats (ENGINE.md §9).
    public init(birthDate: String? = nil, approxAgeYears: Double? = nil, sex: Sex = .unknown, neutered: Neutered = .unknown,
                neuteredDate: String? = nil, lifestyle: Lifestyle? = nil, bcs: Int? = nil, mcs: MuscleCondition? = nil,
                idealWeightKg: Double? = nil, idealWeightSource: ProfileIdealWeightSource? = nil, expectedAdultWeightKg: Double? = nil,
                reproduction: Reproduction = Reproduction(),
                medical: [MedicalFlag] = [], endOfLife: Bool = false, verifiedIntakeKcal: Double? = nil) {
        self.birthDate = birthDate; self.approxAgeYears = approxAgeYears; self.sex = sex; self.neutered = neutered
        self.neuteredDate = neuteredDate; self.lifestyle = lifestyle; self.bcs = bcs; self.mcs = mcs
        self.idealWeightKg = idealWeightKg; self.idealWeightSource = idealWeightKg == nil ? idealWeightSource : idealWeightSource ?? .veterinarian
        self.expectedAdultWeightKg = expectedAdultWeightKg; self.reproduction = reproduction
        self.medical = medical; self.endOfLife = endOfLife; self.verifiedIntakeKcal = verifiedIntakeKcal
    }
    private enum CodingKeys: String, CodingKey {
        case birthDate, approxAgeYears, sex, neutered, neuteredDate, lifestyle, bcs, mcs, idealWeightKg, idealWeightSource, expectedAdultWeightKg
        case reproduction, medical, endOfLife, verifiedIntakeKcal
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        birthDate = try c.decodeIfPresent(String.self, forKey: .birthDate)
        approxAgeYears = try c.decodeIfPresent(Double.self, forKey: .approxAgeYears)
        sex = try c.decode(Sex.self, forKey: .sex); neutered = try c.decode(Neutered.self, forKey: .neutered)
        neuteredDate = try c.decodeIfPresent(String.self, forKey: .neuteredDate)
        lifestyle = try c.decodeIfPresent(Lifestyle.self, forKey: .lifestyle); bcs = try c.decodeIfPresent(Int.self, forKey: .bcs)
        mcs = try c.decodeIfPresent(MuscleCondition.self, forKey: .mcs)
        idealWeightKg = try c.decodeIfPresent(Double.self, forKey: .idealWeightKg)
        // Documents written before the source existed: a stored ideal weight counts as the veterinarian's (ENGINE.md §9).
        let source = try c.decodeIfPresent(ProfileIdealWeightSource.self, forKey: .idealWeightSource)
        idealWeightSource = idealWeightKg == nil ? source : source ?? .veterinarian
        expectedAdultWeightKg = try c.decodeIfPresent(Double.self, forKey: .expectedAdultWeightKg)
        reproduction = try c.decode(Reproduction.self, forKey: .reproduction); medical = try c.decode([MedicalFlag].self, forKey: .medical)
        endOfLife = try c.decode(Bool.self, forKey: .endOfLife)
        verifiedIntakeKcal = try c.decodeIfPresent(Double.self, forKey: .verifiedIntakeKcal)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeNullable(birthDate, forKey: .birthDate); try c.encodeNullable(approxAgeYears, forKey: .approxAgeYears)
        try c.encode(sex, forKey: .sex); try c.encode(neutered, forKey: .neutered); try c.encodeNullable(neuteredDate, forKey: .neuteredDate)
        try c.encodeNullable(lifestyle, forKey: .lifestyle); try c.encodeNullable(bcs, forKey: .bcs); try c.encodeNullable(mcs, forKey: .mcs)
        try c.encodeNullable(idealWeightKg, forKey: .idealWeightKg); try c.encodeNullable(idealWeightSource, forKey: .idealWeightSource)
        try c.encodeNullable(expectedAdultWeightKg, forKey: .expectedAdultWeightKg)
        try c.encode(reproduction, forKey: .reproduction); try c.encode(medical, forKey: .medical); try c.encode(endOfLife, forKey: .endOfLife)
        try c.encodeNullable(verifiedIntakeKcal, forKey: .verifiedIntakeKcal)
    }
}
/// Optional picture for a cat; display names are `icon.*` in shared/messages.json. Keep identical to TypeScript `catIcons`.
public enum CatIcon: String, Codable, CaseIterable, Sendable { case moon, scale, dango, stripes, bolt, paw, fish, yarn, star, heart, leaf, bow }
public struct WeightEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var date: String
    public var weightKg: Double
    public var bcs: Int?
    public init(id: String, date: String, weightKg: Double, bcs: Int? = nil) {
        self.id = id; self.date = date; self.weightKg = weightKg; self.bcs = bcs
    }
    private enum CodingKeys: String, CodingKey { case id, date, weightKg, bcs }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); date = try c.decode(String.self, forKey: .date)
        weightKg = try c.decode(Double.self, forKey: .weightKg); bcs = try c.decodeIfPresent(Int.self, forKey: .bcs)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(date, forKey: .date); try c.encode(weightKg, forKey: .weightKg)
        try c.encodeNullable(bcs, forKey: .bcs)
    }
}
public struct Cat: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var icon: CatIcon?
    public var weightKg: Double
    public var goal: Goal
    public var targetKcal: Double
    public var targetSource: TargetSource
    public var extraKcal: Double
    public var balanceFoodId: String
    public var meals: [Meal]
    public var profile: Profile
    public var weightLog: [WeightEntry]
    public init(id: String, name: String, weightKg: Double, goal: Goal, targetKcal: Double, targetSource: TargetSource,
                extraKcal: Double, balanceFoodId: String, meals: [Meal], profile: Profile = Profile(), weightLog: [WeightEntry] = [],
                icon: CatIcon? = nil) {
        self.id = id; self.name = name; self.icon = icon; self.weightKg = weightKg; self.goal = goal; self.targetKcal = targetKcal
        self.targetSource = targetSource; self.extraKcal = extraKcal; self.balanceFoodId = balanceFoodId; self.meals = meals
        self.profile = profile; self.weightLog = weightLog
    }
    private enum CodingKeys: String, CodingKey {
        case id, name, icon, weightKg, goal, targetKcal, targetSource, extraKcal, balanceFoodId, meals, profile, weightLog
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        icon = try c.decodeIfPresent(CatIcon.self, forKey: .icon); weightKg = try c.decode(Double.self, forKey: .weightKg)
        goal = try c.decode(Goal.self, forKey: .goal); targetKcal = try c.decode(Double.self, forKey: .targetKcal)
        targetSource = try c.decode(TargetSource.self, forKey: .targetSource); extraKcal = try c.decode(Double.self, forKey: .extraKcal)
        balanceFoodId = try c.decode(String.self, forKey: .balanceFoodId); meals = try c.decode([Meal].self, forKey: .meals)
        profile = try c.decode(Profile.self, forKey: .profile); weightLog = try c.decode([WeightEntry].self, forKey: .weightLog)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encodeNullable(icon, forKey: .icon)
        try c.encode(weightKg, forKey: .weightKg); try c.encode(goal, forKey: .goal); try c.encode(targetKcal, forKey: .targetKcal)
        try c.encode(targetSource, forKey: .targetSource); try c.encode(extraKcal, forKey: .extraKcal)
        try c.encode(balanceFoodId, forKey: .balanceFoodId); try c.encode(meals, forKey: .meals); try c.encode(profile, forKey: .profile)
        try c.encode(weightLog, forKey: .weightLog)
    }
}
public struct Activity: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var sharePercent: Double
    public init(id: String, label: String, sharePercent: Double) { self.id = id; self.label = label; self.sharePercent = sharePercent }
}
/// Schema v2 plan. Decoding accepts v1 documents and migrates them (ENGINE.md §9); encoding always writes v2.
public struct Plan: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var name: String
    public var foods: [Food]
    public var cats: [Cat]
    public var activities: [Activity]
    public init(schemaVersion: Int = 2, name: String, foods: [Food], cats: [Cat], activities: [Activity]) {
        self.schemaVersion = schemaVersion; self.name = name; self.foods = foods; self.cats = cats; self.activities = activities
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, name, foods, cats, activities }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decode(Int.self, forKey: .schemaVersion)
        if version == 1 {
            let legacy = try PlanV1(from: decoder)
            try PlanValidator.validateV1Types(legacy)
            self = Migration.migrate(legacy)
            return
        }
        guard version == 2 else { throw PlanError("schemaVersion: only versions 1 and 2 are supported") }
        schemaVersion = version; name = try c.decode(String.self, forKey: .name); foods = try c.decode([Food].self, forKey: .foods)
        cats = try c.decode([Cat].self, forKey: .cats); activities = try c.decode([Activity].self, forKey: .activities)
    }
}

/// Legacy v1 documents (dry food id, wet-only meals, no profile). Accepted by the decoder and migrated.
public struct PlanV1: Codable, Equatable, Sendable {
    public struct FoodV1: Codable, Equatable, Sendable {
        public var id: String, name: String
        public var type: FoodType
        public var energyPerUnit: Double
        public var energyUnit: EnergyUnit
        public var energySource: EnergySource
        public var completeness: Completeness
        public var note: String
    }
    public struct CatV1: Codable, Equatable, Sendable {
        public var id: String, name: String
        public var weightKg: Double
        public var goal: Goal
        public var targetKcal: Double
        public var targetSource: TargetSource
        public var extraKcal: Double
        public var dryFoodId: String
        public var meals: [Meal]
    }
    public var schemaVersion: Int
    public var name: String
    public var foods: [FoodV1]
    public var cats: [CatV1]
    public var activities: [Activity]
}
