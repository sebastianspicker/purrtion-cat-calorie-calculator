import Foundation
import XCTest
@testable import PurrtionCore

/// Minimal JSON tree used to compare engine output with the shared golden expectations.
enum JSONValue: Decodable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    static func of<T: Encodable>(_ value: T) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)) }
}

final class CalculatorTests: XCTestCase {
    static let asOf = "2026-10-09"
    private struct GoldenCase: Decodable {
        let name: String
        let asOf: String
        let plan: Plan
        let expected: JSONValue
    }
    /// Every expected key must match (a null matches a missing key); numbers within 1e-8 absolute or 1e-9 relative; everything else exactly.
    private func mismatches(_ actual: JSONValue?, _ expected: JSONValue, _ path: String) -> [String] {
        switch expected {
        case .number(let e):
            guard case .number(let a)? = actual else { return ["\(path): expected number \(e), got \(String(describing: actual))"] }
            let diff = abs(a - e)
            return diff <= 1e-8 || diff <= 1e-9 * abs(e) ? [] : ["\(path): \(a) != \(e)"]
        case .array(let e):
            guard case .array(let a)? = actual, a.count == e.count else { return ["\(path): expected \(e), got \(String(describing: actual))"] }
            return e.indices.flatMap { mismatches(a[$0], e[$0], "\(path)[\($0)]") }
        case .object(let e):
            guard case .object(let a)? = actual else { return ["\(path): expected an object, got \(String(describing: actual))"] }
            return e.keys.sorted().flatMap { mismatches(a[$0], e[$0]!, "\(path).\($0)") }
        case .null:
            if actual == nil || actual == .null { return [] }
            return ["\(path): expected null, got \(String(describing: actual))"]
        default:
            return actual == expected ? [] : ["\(path): \(String(describing: actual)) != \(expected)"]
        }
    }
    func testGoldenMatcherDetectsDifferences() {
        XCTAssertFalse(mismatches(.number(1), .number(2), "x").isEmpty)
        XCTAssertFalse(mismatches(nil, .number(2), "x").isEmpty)
        XCTAssertFalse(mismatches(.string("a"), .string("b"), "x").isEmpty)
        XCTAssertFalse(mismatches(.object(["a": .number(1)]), .object(["a": .null]), "x").isEmpty)
        XCTAssertTrue(mismatches(nil, .null, "x").isEmpty)
        XCTAssertTrue(mismatches(.number(1_000_000_000.1), .number(1_000_000_000.1 + 1e-4), "x").isEmpty)
    }
    func testSharedGoldenCases() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "golden-cases", withExtension: "json"))
        let cases = try JSONDecoder().decode([GoldenCase].self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(cases.count, 117)
        for c in cases {
            let result = try CalorieCalculator.calculate(c.plan, asOf: c.asOf)
            let actual = try JSONValue.of(result)
            guard case .object(let expected) = c.expected, case .array(let expectedCats)? = expected["cats"] else { return XCTFail("\(c.name): bad expectation") }
            XCTAssertEqual(result.cats.count, expectedCats.count, c.name)
            for case .object(let ec) in expectedCats {
                guard case .string(let id)? = ec["id"], let cat = result.cats.first(where: { $0.id == id }) else { XCTFail("\(c.name): cat missing"); continue }
                var rest = ec; rest["activityRoundedGrams"] = nil
                guard case .object(let actualResult) = actual, case .array(let actualCats)? = actualResult["cats"],
                      let index = result.cats.firstIndex(where: { $0.id == id }) else { return XCTFail() }
                for m in mismatches(actualCats[index], .object(rest), "\(c.name) cats.\(id)") { XCTFail(m) }
                if case .array(let grams)? = ec["activityRoundedGrams"] {
                    XCTAssertEqual(JSONValue.array(cat.activities.map { .number(Double($0.roundedGrams)) }), .array(grams), "\(c.name) \(id) activities")
                }
            }
            for key in ["foods", "totals"] {
                guard let e = expected[key], case .object(let actualResult) = actual else { continue }
                for m in mismatches(actualResult[key], e, "\(c.name) \(key)") { XCTFail(m) }
            }
        }
    }
    func testExampleHouseholdRegression() throws {
        let plan = try PlanCodec.sample(), result = try CalorieCalculator.calculate(plan, asOf: Self.asOf)
        XCTAssertEqual(plan.cats.map(\.targetKcal), [190, 145, 266, 210, 231])
        XCTAssertEqual(result.cats.map(\.balanceGramsRounded), [8, 11, 59, 280, 160])
        XCTAssertEqual(result.cats.map { $0.activities.map(\.roundedGrams) }, [[3, 2, 3], [3, 3, 5], [18, 18, 23], [84, 84, 112], [48, 48, 64]])
        XCTAssertEqual(result.cats.map(\.fixedGrams), [170, 140, 40, 0, 0])
        XCTAssertEqual(result.totals.balanceGramsRounded, 518)
        XCTAssertEqual(result.totals.balanceByFood.map(\.foodId), ["dry-adult", "dry-kitten", "wet-fish", "raw-mix"])
        XCTAssertEqual(result.totals.balanceByFood.map(\.gramsRounded), [19, 59, 280, 160])
        XCTAssertEqual(result.cats.map(\.estimate.status), [.ok, .ok, .ok, .referenceOnly, .ok])
        XCTAssertEqual(result.cats.map(\.estimate.equation), [.adultFediaf, .weightLossAaha, .kittenNrc, .adultFediaf, .adultFediaf])
        XCTAssertEqual(result.cats.map { ($0.estimate.startKcal ?? 0).rounded() }, [190, 145, 266, 183, 231])
        XCTAssertEqual(result.cats[1].trend.suggestion, Suggestion(action: .none, reason: .onTrack, suggestedKcal: nil))
        guard case .ok(let oskar) = result.cats[1].nutrition, case .ok(let tiger) = result.cats[3].nutrition else { return XCTFail() }
        XCTAssertEqual(oskar.warnings, [.proteinBelow5gPerKgIbw]); XCTAssertEqual(tiger.warnings, []); XCTAssertEqual(tiger.notes, [.ckdProteinVet])
    }
    func testSourceAndCompletenessWarnings() throws {
        let r = try CalorieCalculator.calculate(PlanCodec.sample(), asOf: Self.asOf)
        XCTAssertEqual(r.cats.map(\.warnings), [[.estimatedEnergy], [.estimatedEnergy, .provisionalTarget], [.provisionalTarget], [],
                                                [.estimatedEnergy, .unknownCompleteness]])
    }
    func testNoAutomaticDietPrescription() throws {
        var plan = try PlanCodec.sample()
        let original = try CalorieCalculator.calculate(plan, asOf: Self.asOf)
        plan.cats[0].weightKg = 4; plan.cats[0].goal = .gain
        XCTAssertEqual(try CalorieCalculator.calculate(plan, asOf: Self.asOf).cats[0].balanceGramsExact, original.cats[0].balanceGramsExact, accuracy: 1e-8)
    }
    func testLabelUnitConversionsAreInvariant() throws {
        let food = try PlanCodec.sample().foods[2]
        XCTAssertEqual(try CalorieCalculator.kcalPerGram(food), 1600 / 4.184 / 100, accuracy: 1e-12)
        for unit in EnergyUnit.allCases {
            var converted = food
            converted.energyPerUnit = try CalorieCalculator.energyInUnit(food, unit: unit); converted.energyUnit = unit
            XCTAssertEqual(try CalorieCalculator.kcalPerGram(converted), try CalorieCalculator.kcalPerGram(food), accuracy: 1e-10)
        }
    }
    func testExactlyTenPercentIsNotFlagged() throws {
        var plan = try PlanCodec.sample(); plan.cats[0].extraKcal = 19
        XCTAssertFalse(try CalorieCalculator.calculate(plan, asOf: Self.asOf).cats[0].warnings.contains(.extrasOverTenPercent))
        plan.cats[0].extraKcal = 19.1
        XCTAssertTrue(try CalorieCalculator.calculate(plan, asOf: Self.asOf).cats[0].warnings.contains(.extrasOverTenPercent))
    }
    func testComplementaryBalanceFoodIsFlagged() throws {
        var plan = try PlanCodec.sample(); plan.foods[2].completeness = .complementary
        XCTAssertTrue(try CalorieCalculator.calculate(plan, asOf: Self.asOf).cats[0].warnings.contains(.complementaryBalanceFood))
    }
    func testAnalysisEnergyIsUsedAndFlaggedAsEstimate() throws {
        var plan = try PlanCodec.sample()
        let analysis = Analysis(protein: 34, fat: 14, fibre: 3, ash: 7, moisture: 8)
        plan.foods[2].energySource = .analysis; plan.foods[2].energyPerUnit = nil; plan.foods[2].analysis = analysis
        plan.cats[0].meals = []
        XCTAssertEqual(try CalorieCalculator.kcalPerGram(plan.foods[2]), FoodAnalysis.meKcalPer100g(analysis) / 100, accuracy: 1e-12)
        let result = try CalorieCalculator.calculate(plan, asOf: Self.asOf)
        XCTAssertEqual(result.cats[0].warnings, [.estimatedEnergy])
        XCTAssertNotNil(result.foods[2].analysis)
    }
    func testRoundTripAndExplicitNulls() throws {
        let plan = try PlanCodec.sample()
        let data = try PlanCodec.encode(plan)
        XCTAssertEqual(try PlanCodec.decode(data), plan)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"neuteredDate\" : null"))
        XCTAssertTrue(json.contains("\"energyPerUnit\" : null"))
        XCTAssertTrue(json.contains("\"idealWeightSource\" : null"))
        XCTAssertTrue(json.contains("\"idealWeightSource\" : \"estimate\""))
        XCTAssertTrue(json.contains("\"schemaVersion\" : 2"))
        XCTAssertTrue(json.hasSuffix("\n"))
    }
    func testFullProfileAndWeightLogRoundTrip() throws {
        var plan = try PlanCodec.sample()
        plan.cats[0].profile = Profile(birthDate: "2020-02-29", sex: .female, neutered: .yes, neuteredDate: "2020-09-01", lifestyle: .sedentary,
            bcs: 7, mcs: .mild, idealWeightKg: 5, idealWeightSource: .estimate, expectedAdultWeightKg: nil, medical: [.ckd, .diabetes], verifiedIntakeKcal: 240)
        plan.cats[0].weightLog = [WeightEntry(id: "w1", date: "2026-09-01", weightKg: 6.1, bcs: 7), WeightEntry(id: "w2", date: "2026-10-01", weightKg: 6)]
        plan.cats[1].profile.reproduction = Reproduction(status: .lactation, litterSize: 4, lactationWeek: 3, preBreedingWeightKg: 4.2)
        XCTAssertEqual(try PlanCodec.decode(PlanCodec.encode(plan)), plan)
    }
    func testCSVColumnsAndFormulaEscape() throws {
        var plan = try PlanCodec.sample(); plan.cats[0].name = "=HYPERLINK(\"x\")"
        let csv = try PlanCodec.csv(plan, asOf: Self.asOf)
        XCTAssertTrue(csv.contains("\"'=HYPERLINK(\"\"x\"\")\""))
        let header = "\"Cat\",\"Weight (kg)\",\"Goal\",\"Target (kcal/day)\",\"Fixed meals (g/day)\",\"Fixed meals (kcal/day)\",\"Extras (kcal/day)\",\"Balance food\",\"Balance food calculated (g/day)\",\"Balance food rounded (g/day)\",\"Calories after rounding\",\"Estimate status\",\"Estimate start (kcal/day)\",\"Estimate range (kcal/day)\",\"Warnings\""
        XCTAssertTrue(csv.hasPrefix(header + "\r\n"))
        let rows = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(rows.count, 7, csv) // header, five cats, trailing empty
        // Same cells as the TypeScript planToCSV.
        XCTAssertTrue(rows[1].hasPrefix("\"'=HYPERLINK(\"\"x\"\")\",\"4\",\"maintain\",\"190\",\"170\",\"159.13329400000003\",\"0\""), rows[1])
        XCTAssertTrue(rows[1].hasSuffix(",\"Example dry food, adult\",\"8.0716\",\"8\",\"189.73\",\"ok\",\"190\",\"161–218\",\"estimated-energy\""), rows[1])
        XCTAssertEqual(rows[4], "\"Tiger\",\"3.8\",\"maintain\",\"210\",\"0\",\"0\",\"0\",\"Example wet food, fish in jelly\",\"280.0000\",\"280\",\"210.00\",\"reference-only\",\"183\",\"156–229\",\"\"")
        plan.cats[2].profile.birthDate = nil
        let needs = try PlanCodec.csv(plan, asOf: Self.asOf).components(separatedBy: "\r\n")[3]
        XCTAssertTrue(needs.contains(",\"needs-input\",\"\",\"\","), needs)
    }
    func testCSVFormulaGuardUsesFirstUnicodeScalar() {
        for risky in ["\n=1", "\r=1", "=\u{301}1", "@x", "-1", "+1", "\t1", "=1"] {
            XCTAssertTrue(PlanCodec.csvCell(risky).hasPrefix("\"'"), risky.debugDescription)
        }
        XCTAssertEqual(PlanCodec.csvCell("Luna"), "\"Luna\"")
    }
    func testRoundingSumsContainersRatherThanHousehold() throws {
        var plan = try PlanCodec.sample()
        for index in plan.cats.indices { plan.cats[index].meals = []; plan.cats[index].targetKcal = 10 }
        let result = try CalorieCalculator.calculate(plan, asOf: Self.asOf)
        XCTAssertEqual(result.cats.map(\.balanceGramsRounded), [3, 3, 3, 13, 7])
        XCTAssertEqual(result.totals.balanceGramsRounded, 29)
        XCTAssertEqual(Int(result.totals.balanceGramsExact.rounded()), 28)
    }
    func testInvalidNumbersAndAsOfRejected() throws {
        for value in [Double.nan, Double.infinity, -1, 0] {
            var plan = try PlanCodec.sample(); plan.cats[0].targetKcal = value
            XCTAssertThrowsError(try CalorieCalculator.calculate(plan, asOf: Self.asOf))
        }
        let plan = try PlanCodec.sample()
        for asOf in ["", "2026-13-01", "2026-1-01", "today"] { XCTAssertThrowsError(try CalorieCalculator.calculate(plan, asOf: asOf), asOf) }
    }
    func testHalfUpAndStableActivityTieBreak() throws {
        let activities = [Activity(id: "a", label: "A", sharePercent: 50), Activity(id: "b", label: "B", sharePercent: 50)]
        XCTAssertEqual(try CalorieCalculator.allocateRounded(5, activities: activities), [3, 2])
        XCTAssertEqual(try CalorieCalculator.allocateRounded(2.5, activities: activities), [2, 1])
    }
    func testInvalidRERAndAllocationsRejected() throws {
        XCTAssertThrowsError(try CalorieCalculator.rer(0))
        XCTAssertThrowsError(try CalorieCalculator.rer(.infinity))
        XCTAssertThrowsError(try CalorieCalculator.allocateRounded(-1, activities: PlanCodec.sample().activities))
        XCTAssertThrowsError(try CalorieCalculator.allocateRounded(5, activities: []))
    }
    func testConservationAcrossTwoHundredScenarios() throws {
        var state: UInt32 = 73
        func random() -> Double { state = 1664525 &* state &+ 1013904223; return Double(state) / 4294967296 }
        for _ in 0..<200 {
            var plan = try PlanCodec.sample()
            for index in plan.cats.indices {
                plan.cats[index].targetKcal = 180 + random() * 160; plan.cats[index].extraKcal = random() * 20
                for meal in plan.cats[index].meals.indices { plan.cats[index].meals[meal].grams = random() * 100 }
            }
            let result = try CalorieCalculator.calculate(plan, asOf: Self.asOf)
            for (index, cat) in result.cats.enumerated() {
                XCTAssertGreaterThanOrEqual(cat.balanceGramsExact, 0)
                XCTAssertEqual(cat.activities.reduce(0) { $0 + $1.roundedGrams }, cat.balanceGramsRounded)
                XCTAssertEqual(cat.fixedKcal + cat.extraKcal + cat.balanceKcal, plan.cats[index].targetKcal + cat.overBudgetKcal, accuracy: 1e-8)
            }
        }
    }
}
