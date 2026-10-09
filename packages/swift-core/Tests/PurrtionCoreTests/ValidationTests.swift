import Foundation
import XCTest
@testable import PurrtionCore

/// Migration and validation tests, mirroring packages/core/test/validation.test.mjs. Documents are mutated as JSON so decoding and validation are both exercised.
final class ValidationTests: XCTestCase {
    typealias JSON = [String: Any]
    static var analysis: JSON { ["moisture": 78.0, "protein": 10.0, "fat": 5.0, "fibre": 0.5, "ash": 2.0, "kind": "prepared"] }
    func seedObject() throws -> JSON {
        try XCTUnwrap(JSONSerialization.jsonObject(with: PlanCodec.encode(PlanCodec.sample())) as? JSON)
    }
    /// Sets (or, with nil, removes) the value at `path` (String keys and Int indices) in a JSON tree.
    func setting(_ root: Any, _ path: ArraySlice<Any>, _ value: Any?) -> Any {
        guard let head = path.first else { return value as Any }
        if let key = head as? String, var object = root as? JSON {
            if path.count == 1 { object[key] = value } else { object[key] = setting(object[key] as Any, path.dropFirst(), value) }
            return object
        }
        if let index = head as? Int, var array = root as? [Any] { array[index] = setting(array[index], path.dropFirst(), value); return array }
        return root
    }
    func data(_ path: [Any], _ value: Any?, in root: JSON? = nil) throws -> Data {
        let object = try root ?? seedObject()
        return try JSONSerialization.data(withJSONObject: setting(object, path[...], value))
    }
    /// The raw v1 document of the shared golden case `v1-document-is-migrated`.
    func v1Object() throws -> JSON {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "golden-cases", withExtension: "json"))
        let cases = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [JSON])
        let legacy = try XCTUnwrap(cases.first { $0["name"] as? String == "v1-document-is-migrated" })
        return try XCTUnwrap(legacy["plan"] as? JSON)
    }
    /// The v2 form of that document, written out by hand (ENGINE.md §9).
    func v1AsV2() throws -> Plan {
        let v1 = try JSONDecoder().decode(PlanV1.self, from: JSONSerialization.data(withJSONObject: v1Object()))
        return Plan(name: v1.name,
            foods: v1.foods.map { Food(id: $0.id, name: $0.name, type: $0.type, energyPerUnit: $0.energyPerUnit, energyUnit: $0.energyUnit,
                                       energySource: $0.energySource, completeness: $0.completeness, lifeStageClaim: .unknown, analysis: nil, note: $0.note) },
            cats: v1.cats.map { Cat(id: $0.id, name: $0.name, weightKg: $0.weightKg, goal: $0.goal, targetKcal: $0.targetKcal, targetSource: $0.targetSource,
                                    extraKcal: $0.extraKcal, balanceFoodId: $0.dryFoodId, meals: $0.meals, profile: Profile(), weightLog: []) },
            activities: v1.activities)
    }

    func testMigrationOfV1MatchesItsV2Form() throws {
        let migrated = try PlanCodec.decode(JSONSerialization.data(withJSONObject: v1Object()))
        XCTAssertEqual(migrated, try v1AsV2())
        XCTAssertEqual(migrated.schemaVersion, 2); XCTAssertNil(Profile().idealWeightSource)
        for c in migrated.cats { XCTAssertEqual(c.balanceFoodId, "dry"); XCTAssertEqual(c.profile, Profile()); XCTAssertEqual(c.weightLog, []) }
        for f in migrated.foods { XCTAssertNil(f.analysis); XCTAssertEqual(f.lifeStageClaim, .unknown) }
    }
    func testV1AllocationResultsAreIdenticalAfterMigration() throws {
        let migrated = try PlanCodec.decode(JSONSerialization.data(withJSONObject: v1Object()))
        let a = try CalorieCalculator.calculate(migrated, asOf: "2026-10-09"), b = try CalorieCalculator.calculate(v1AsV2(), asOf: "2026-10-09")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.cats.map(\.balanceGramsRounded), [26, 24, 39])
    }
    func testExportOfV1ImportIsV2() throws {
        let plan = try PlanCodec.decode(JSONSerialization.data(withJSONObject: v1Object()))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: PlanCodec.encode(plan)) as? JSON)
        XCTAssertEqual(json["schemaVersion"] as? Int, 2)
        XCTAssertNotNil((json["cats"] as? [JSON])?[0]["balanceFoodId"]); XCTAssertNil((json["cats"] as? [JSON])?[0]["dryFoodId"])
    }
    func testV1KeepsItsTypeRules() throws {
        let v1 = try v1Object()
        XCTAssertThrowsError(try PlanCodec.decode(data(["cats", 0, "dryFoodId"], "wet-a", in: v1))) { XCTAssertTrue("\($0)".contains("dry food")) }
        XCTAssertThrowsError(try PlanCodec.decode(data(["cats", 0, "meals", 0, "foodId"], "dry", in: v1))) { XCTAssertTrue("\($0)".contains("wet food")) }
        XCTAssertThrowsError(try PlanCodec.decode(data(["foods", 0, "energySource"], "analysis", in: v1)))
    }
    func testV2AllowsAnyFoodForMealsAndBalance() throws {
        var object = try seedObject()
        object = try XCTUnwrap(setting(object, ["cats", 0, "balanceFoodId"], "wet-chicken") as? JSON)
        let plan = try PlanCodec.decode(data(["cats", 0, "meals", 0, "foodId"], "dry-adult", in: object))
        XCTAssertEqual(plan.cats[0].balanceFoodId, "wet-chicken")
    }
    func testNullableFieldsAcceptMissingKeyOrNull() throws {
        var object = try seedObject()
        object = try XCTUnwrap(setting(object, ["cats", 0, "profile", "bcs"], nil) as? JSON)
        object = try XCTUnwrap(setting(object, ["foods", 1, "analysis"], nil) as? JSON)
        object = try XCTUnwrap(setting(object, ["foods", 2, "energyPerUnit"], nil) as? JSON)
        object = try XCTUnwrap(setting(object, ["foods", 2, "energySource"], "analysis") as? JSON)
        object = try XCTUnwrap(setting(object, ["foods", 2, "analysis"], Self.analysis) as? JSON)
        let plan = try PlanCodec.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(plan.cats[0].profile.bcs); XCTAssertNil(plan.foods[1].analysis); XCTAssertNil(plan.foods[2].energyPerUnit)
        let explicitNull = try PlanCodec.decode(data(["foods", 1, "analysis"], NSNull()))
        XCTAssertNil(explicitNull.foods[1].analysis)
    }
    /// D3: the source is nil if and only if the ideal weight is nil; a missing or null source with a weight decodes as veterinarian.
    func testCatIconRoundTripAndMissingIcon() throws {
        XCTAssertEqual(try PlanCodec.sample().cats.map(\.icon), [.moon, .scale, .dango, .stripes, .bolt])
        var object = try seedObject()
        object = try XCTUnwrap(setting(object, ["cats", 0, "icon"], "heart") as? JSON)
        object = try XCTUnwrap(setting(object, ["cats", 1, "icon"], nil) as? JSON) // key missing
        object = try XCTUnwrap(setting(object, ["cats", 2, "icon"], NSNull()) as? JSON)
        let plan = try PlanCodec.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(plan.cats.map(\.icon), [.heart, nil, nil, .stripes, .bolt])
        XCTAssertEqual(try PlanCodec.decode(PlanCodec.encode(plan)), plan)
        XCTAssertTrue(String(decoding: try PlanCodec.encode(plan), as: UTF8.self).contains("\"icon\" : null"))
        XCTAssertTrue(try PlanCodec.decode(JSONSerialization.data(withJSONObject: v1Object())).cats.allSatisfy { $0.icon == nil })
        XCTAssertEqual(Set(CatIcon.allCases.map(\.rawValue)), ["moon", "scale", "dango", "stripes", "bolt", "paw", "fish", "yarn", "star", "heart", "leaf", "bow"])
    }
    func testIdealWeightSourceDecodingAndPersistence() throws {
        var object = try seedObject()
        object = try XCTUnwrap(setting(object, ["cats", 0, "profile", "idealWeightKg"], 3.8) as? JSON) // source stays null
        object = try XCTUnwrap(setting(object, ["cats", 4, "profile", "idealWeightKg"], 3.4) as? JSON)
        object = try XCTUnwrap(setting(object, ["cats", 4, "profile", "idealWeightSource"], nil) as? JSON) // key missing
        let plan = try PlanCodec.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(plan.cats.map(\.profile.idealWeightSource), [.veterinarian, .estimate, nil, nil, .veterinarian])
        XCTAssertEqual(try PlanCodec.decode(PlanCodec.encode(plan)), plan)
        XCTAssertEqual(try CalorieCalculator.calculate(plan, asOf: "2026-10-09").cats[1].estimate.idealWeight?.source, .estimate)
        XCTAssertEqual(Profile(idealWeightKg: 4).idealWeightSource, .veterinarian)
        var invalid = try PlanCodec.sample(); invalid.cats[0].profile.idealWeightSource = .estimate
        XCTAssertThrowsError(try PlanValidator.validate(invalid))
    }
    func testPlanValidatorRejectsProgrammaticMistakes() throws {
        var plan = try PlanCodec.sample(); plan.cats[0].balanceFoodId = "ghost"
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.schemaVersion = 3
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.schemaVersion = 1
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.cats[0].meals[0].foodId = "missing"
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.foods[1].id = plan.foods[0].id
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.cats[1].id = plan.cats[0].id
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.cats[0].meals[1].id = plan.cats[0].meals[0].id
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.activities[0].sharePercent = 29
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.cats = []
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.activities = []
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.cats[0].meals[0].grams = -1
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.foods[3].energyPerUnit = 0
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.foods[3].energyPerUnit = nil
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.cats[0].profile.medical = [.ckd, .ckd]
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.cats[0].profile.bcs = 10
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = try PlanCodec.sample(); plan.cats[0].weightLog = [WeightEntry(id: "w", date: "2026-02-30", weightKg: 4)]
        XCTAssertThrowsError(try PlanValidator.validate(plan))
    }
    func testFutureSchemaBadJSONAndOversizeRejected() throws {
        XCTAssertThrowsError(try PlanCodec.decode(data(["schemaVersion"], 3)))
        XCTAssertThrowsError(try PlanCodec.decode(data(["schemaVersion"], nil)))
        XCTAssertThrowsError(try PlanCodec.decode(Data("{".utf8)))
        XCTAssertThrowsError(try PlanCodec.decode(Data(repeating: 32, count: PlanCodec.maximumImportBytes + 1)))
    }

    func testV2Rejects() throws {
        let tooMany = (0..<1001).map { ["id": "w\($0)", "date": "2026-02-01", "weightKg": 4.0, "bcs": NSNull()] as JSON }
        func entry(_ id: String = "w", _ date: String = "2026-02-01", _ kg: Double = 4, _ bcs: Any = NSNull()) -> JSON { ["id": id, "date": date, "weightKg": kg, "bcs": bcs] }
        let profile: [Any] = ["cats", 0, "profile"]
        let cases: [(String, [Any], Any?)] = [
            ("energySource analysis without analysis", ["foods", 0, "analysis"], NSNull()),
            ("null energy without analysis source", ["foods", 1, "energyPerUnit"], NSNull()),
            ("unknown energy source", ["foods", 0, "energySource"], "guess"),
            ("unknown life-stage claim", ["foods", 0, "lifeStageClaim"], "senior"),
            ("missing life-stage claim", ["foods", 0, "lifeStageClaim"], nil),
            ("analysis value above 100", ["foods", 0, "analysis"], Self.analysis.merging(["protein": 101.0]) { $1 }),
            ("negative analysis value", ["foods", 0, "analysis"], Self.analysis.merging(["fat": -1.0]) { $1 }),
            ("analysis sum above 100", ["foods", 0, "analysis"], Self.analysis.merging(["protein": 20.0]) { $1 }),
            ("null moisture on wet food", ["foods", 0, "analysis"], Self.analysis.merging(["moisture": NSNull()]) { $1 }),
            ("moisture of 100", ["foods", 3, "analysis"], ["moisture": 100.0, "protein": 0.0, "fat": 0.0, "fibre": 0.0, "ash": 0.0, "kind": "prepared"] as JSON),
            ("unknown analysis kind", ["foods", 0, "analysis"], Self.analysis.merging(["kind": "raw"]) { $1 }),
            ("missing profile", ["cats", 0, "profile"], nil),
            ("missing weight log", ["cats", 0, "weightLog"], nil),
            ("invalid birth date", profile + ["birthDate"], "2023-02-29"),
            ("non-ISO birth date", profile + ["birthDate"], "09.10.2020"),
            ("invalid neutered date", profile + ["neuteredDate"], "2026-13-01"),
            ("approximate age above 30", profile + ["approxAgeYears"], 31.0),
            ("unknown sex", profile + ["sex"], "x"),
            ("unknown neutered value", profile + ["neutered"], true),
            ("unknown lifestyle", profile + ["lifestyle"], "lazy"),
            ("fractional BCS", profile + ["bcs"], 5.5),
            ("BCS above 9", profile + ["bcs"], 10),
            ("unknown MCS", profile + ["mcs"], "none"),
            ("ideal weight below 0.1 kg", profile + ["idealWeightKg"], 0.05),
            ("ideal weight source without ideal weight", profile + ["idealWeightSource"], "estimate"),
            ("ideal weight cleared but source kept", ["cats", 1, "profile", "idealWeightKg"], NSNull()),
            ("unknown cat icon", ["cats", 0, "icon"], "dragon"),
            ("non-string cat icon", ["cats", 0, "icon"], 3),
            ("unknown ideal weight source", ["cats", 1, "profile", "idealWeightSource"], "bcs-estimate"),
            ("expected adult weight above 40 kg", profile + ["expectedAdultWeightKg"], 41.0),
            ("unknown reproduction status", profile + ["reproduction", "status"], "pregnant"),
            ("litter size 13", profile + ["reproduction", "litterSize"], 13),
            ("fractional lactation week", profile + ["reproduction", "lactationWeek"], 2.5),
            ("missing reproduction", profile + ["reproduction"], nil),
            ("unknown medical flag", profile + ["medical"], ["flu"]),
            ("duplicate medical flag", profile + ["medical"], ["ckd", "ckd"]),
            ("non-boolean end of life", profile + ["endOfLife"], "no"),
            ("verified intake above 3000", profile + ["verifiedIntakeKcal"], 3001.0),
            ("weight entry with invalid date", ["cats", 0, "weightLog"], [entry("w", "2026-02-30")]),
            ("weight entry below 0.1 kg", ["cats", 0, "weightLog"], [entry("w", "2026-02-01", 0)]),
            ("weight entry BCS 0", ["cats", 0, "weightLog"], [entry("w", "2026-02-01", 4, 0)]),
            ("duplicate weight entry ID", ["cats", 0, "weightLog"], [entry("w"), entry("w", "2026-02-02")]),
            ("more than 1000 weight entries", ["cats", 0, "weightLog"], tooMany),
            ("dryFoodId instead of balanceFoodId in v2", ["cats", 0, "balanceFoodId"], nil),
            ("balance food not in library", ["cats", 0, "balanceFoodId"], "ghost"),
            ("meal food not in library", ["cats", 0, "meals", 0, "foodId"], "ghost"),
            ("target above 3000", ["cats", 0, "targetKcal"], 3001.0),
            ("cat weight 0", ["cats", 0, "weightKg"], 0.0),
            ("bad id characters", ["cats", 0, "id"], "-bad id"),
            ("empty name", ["name"], "  "),
            ("activity shares not 100", ["activities", 0, "sharePercent"], 29.0),
            ("implausible computed density", ["foods", 0], ["id": "wet-chicken", "name": "Example", "type": "wet", "energyPerUnit": NSNull(), "energyUnit": "kcal/100g",
                "energySource": "analysis", "completeness": "unknown", "lifeStageClaim": "unknown", "note": "",
                "analysis": ["moisture": 99.5, "protein": 0.2, "fat": 0.0, "fibre": 0.0, "ash": 0.3, "kind": "fresh"] as JSON] as JSON),
        ]
        XCTAssertGreaterThanOrEqual(cases.count, 20)
        for (name, path, value) in cases { XCTAssertThrowsError(try PlanCodec.decode(data(path, value)), name) }
        // The unmodified seed decodes, so every rejection above is caused by its mutation.
        XCTAssertNoThrow(try PlanCodec.decode(data(["name"], "Valid")))
    }
    func testIdsBlankAndTextCharacterRules() throws {
        func rejects(_ path: [Any], _ value: String, _ label: String) {
            XCTAssertThrowsError(try PlanCodec.decode(data(path, value)), label)
        }
        rejects(["cats", 0, "id"], "abc\n", "id with trailing newline")
        rejects(["name"], "\u{FEFF}", "BOM-only name is blank")
        rejects(["name"], " \u{00A0}\u{2028}\u{3000}", "JS whitespace-only name is blank")
        XCTAssertNoThrow(try PlanCodec.decode(data(["name"], "\u{200B}")), "U+200B is not blank")
        rejects(["cats", 0, "name"], "Lu\u{202E}na", "bidi override in name")
        rejects(["cats", 0, "name"], "Lu\u{2067}na", "bidi isolate in name")
        rejects(["cats", 0, "name"], "Lu\nna", "newline in name")
        rejects(["cats", 0, "name"], "Lu\u{7F}na", "DEL in name")
        rejects(["cats", 0, "name"], "Lu\u{0}na", "NUL in name")
        rejects(["cats", 0, "meals", 0, "label"], "A\tB", "tab in label")
        rejects(["activities", 0, "label"], "A\u{202A}B", "bidi embedding in activity label")
        rejects(["foods", 0, "note"], "a\rb", "CR in note")
        rejects(["foods", 0, "note"], "a\u{202E}b", "bidi override in note")
        XCTAssertNoThrow(try PlanCodec.decode(data(["foods", 0, "note"], "line one\n\tline two")), "note keeps tab and LF")
    }
    func testAPlanWithMissingKeysAndUnknownFieldsBehaves() throws {
        XCTAssertNoThrow(try PlanCodec.decode(data(["extra"], "ignored")))
        XCTAssertThrowsError(try PlanCodec.decode(data(["cats", 0, "targetKcal"], nil)))
    }
}
