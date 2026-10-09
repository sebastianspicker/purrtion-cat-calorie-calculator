import Foundation
import XCTest
@testable import PurrtionCore

/// Unit tests for the v2 engine modules, mirroring packages/core/test/engine.test.mjs.
final class EngineTests: XCTestCase {
    let asOf = "2026-10-09"
    func near(_ actual: Double?, _ expected: Double, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("nil, expected \(expected) \(message)", file: file, line: line) }
        XCTAssertLessThanOrEqual(abs(actual - expected), 1e-9 * max(1, abs(expected)), "\(actual) != \(expected) \(message)", file: file, line: line)
    }
    func round2(_ actual: Double?, _ expected: Double, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(((actual ?? .nan) * 100).rounded() / 100, expected, file: file, line: line)
    }
    func day(_ offset: Int) -> String {
        let seconds = TimeInterval((Dates.dayNumber(asOf)! + offset) * 86400)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: seconds))
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    /// A 5-year-old neutered cat with BCS 5; adjust through the closures.
    func cat(_ edit: (inout Cat) -> Void = { _ in }, _ editProfile: (inout Profile) -> Void = { _ in }) -> Cat {
        var c = Cat(id: "c", name: "Cat", weightKg: 4, goal: .maintain, targetKcal: 190, targetSource: .owner, extraKcal: 0, balanceFoodId: "dry", meals: [])
        c.profile.approxAgeYears = 5; c.profile.neutered = .yes; c.profile.bcs = 5
        edit(&c); editProfile(&c.profile)
        return c
    }
    func entries(_ pairs: [(Int, Double)]) -> [WeightEntry] {
        pairs.enumerated().map { WeightEntry(id: "w\($0.offset)", date: day($0.element.0), weightKg: $0.element.1) }
    }
    let wet = Analysis(protein: 10, fat: 5, fibre: 0.5, ash: 2, moisture: 78)
    let dry = Analysis(protein: 34, fat: 14, fibre: 3, ash: 7, moisture: 8)
    func estimate(_ c: Cat, _ stops: [ReferCode] = []) throws -> EnergyEstimate { try Estimator.estimate(c, asOf: asOf, trendStops: stops) }

    func testBalanceWarningsUseDeliveredGrams() throws {
        for (target, fixed, grams, overTen) in [(190.0, 189.6, 0, false), (199, 179.4, 20, true), (194, 174.6, 19, false)] {
            let complete = Food(id: "fixed", name: "Fixed", type: .wet, energyPerUnit: 100, energyUnit: .kcalPer100g, energySource: .label, completeness: .complete)
            var balance = Food(id: "dry", name: "Balance", type: .dry, energyPerUnit: 100, energyUnit: .kcalPer100g, energySource: .estimate, completeness: .complementary)
            let c = cat({ $0.targetKcal = target; $0.meals = [Meal(id: "m", label: "Fixed meal", foodId: "fixed", grams: fixed)] })
            var plan = Plan(name: "Rounding", foods: [complete, balance], cats: [c], activities: [Activity(id: "a", label: "Bowl", sharePercent: 100)])
            let r = try CalorieCalculator.calculate(plan, asOf: asOf).cats[0]
            XCTAssertEqual(r.balanceGramsRounded, grams)
            XCTAssertEqual(r.warnings.contains(.complementaryBalanceFood), grams > 0)
            XCTAssertEqual(r.warnings.contains(.estimatedEnergy), grams > 0)
            XCTAssertEqual(r.warnings.contains(.extrasOverTenPercent), overTen)
            balance.completeness = .unknown; plan.foods[1] = balance
            XCTAssertEqual(try CalorieCalculator.calculate(plan, asOf: asOf).cats[0].warnings.contains(.unknownCompleteness), grams > 0)
        }
    }
    func testScienceAnchors() throws {
        round2(Estimator.mer(75, 4), 189.86); round2(Estimator.mer(100, 4), 253.15); round2(try Estimator.rer(4), 197.99)
        round2(try estimate(cat({ $0.weightKg = 2 }, { $0.approxAgeYears = nil; $0.birthDate = day(-91); $0.expectedAdultWeightKg = 4 })).startKcal, 266.32)
        round2(try estimate(cat({ _ in }, { $0.approxAgeYears = 3; $0.reproduction = Reproduction(status: .gestation, preBreedingWeightKg: 4) })).startKcal, 354.41)
        round2(try estimate(cat({ _ in }, { $0.approxAgeYears = 3; $0.reproduction = Reproduction(status: .lactation, litterSize: 4, lactationWeek: 4) })).startKcal, 541.15)
        round2(try estimate(cat({ $0.weightKg = 6; $0.goal = .loss }, { $0.bcs = 8 })).startKcal, 167.17)
    }
    func testGainRangeStaysOrderedAtFloor() throws {
        let e = try estimate(cat({ $0.goal = .gain }, {
            $0.bcs = 4; $0.lifestyle = .sedentary; $0.idealWeightKg = 8; $0.idealWeightSource = .veterinarian
        }))
        XCTAssertEqual(e.equation, .adultGain); round2(e.floorKcal, 199.79)
        near(e.lowKcal, e.floorKcal!); near(e.startKcal, e.floorKcal!); near(e.highKcal, e.floorKcal!)
        for bw in [0.1, 1, 4, 8, 40] { for ibw in [0.1, 1, 4, 8, 40] {
            for lifestyle in [Lifestyle.sedentary, .typical, .active] { for goal in [Goal.gain, .maintain, .loss] {
                let result = try estimate(cat({ $0.weightKg = bw; $0.goal = goal }, {
                    $0.bcs = 4; $0.lifestyle = lifestyle; $0.idealWeightKg = ibw; $0.idealWeightSource = .veterinarian
                }))
                XCTAssertLessThanOrEqual(result.floorKcal!, result.lowKcal!)
                XCTAssertLessThanOrEqual(result.lowKcal!, result.startKcal!)
                XCTAssertLessThanOrEqual(result.startKcal!, result.highKcal!)
            }}
        }}
    }
    func testAllTrendReductionsRespectFloorAndDirection() throws {
        for goal in [Goal.maintain, .gain, .loss] { for target in [100.0, 120, 140, 190] {
            let latest = goal == .loss ? 4.0 : 4.15
            let c = cat({
                $0.goal = goal; $0.targetKcal = target; $0.weightKg = latest
                $0.weightLog = entries([(-21, 4), (0, latest)])
            }, { $0.bcs = goal == .gain ? 4 : goal == .loss ? 6 : 5 })
            let series = try TrendAnalysis.weightSeries(c, asOf: asOf)
            let stops = try TrendAnalysis.stops(c, series: series, stage: Estimator.stageOf(c, asOf: asOf))
            let e = try estimate(c, stops)
            let suggestion = try XCTUnwrap(TrendAnalysis.trend(c, asOf: asOf, estimate: e, series: series).suggestion)
            if 0.9 * target < e.floorKcal! {
                XCTAssertEqual(suggestion.action, .refer); XCTAssertEqual(suggestion.reason, .atFloor)
                XCTAssertNil(suggestion.suggestedKcal)
            } else {
                XCTAssertEqual(suggestion.action, .decrease); near(suggestion.suggestedKcal, 0.9 * target)
                XCTAssertLessThan(suggestion.suggestedKcal!, target)
                XCTAssertGreaterThanOrEqual(suggestion.suggestedKcal!, e.floorKcal!)
            }
            XCTAssertEqual(c.targetKcal, target)
        }}
    }
    /// SCIENCE.md §12.2 weight-loss vectors (D1).
    func testWeightLossStartVectors() throws {
        let ibw = 6 / 1.3, floor = 0.6 * (try Estimator.rer(ibw))
        func loss(_ edit: @escaping (inout Profile) -> Void) throws -> EnergyEstimate {
            try estimate(cat({ $0.weightKg = 6; $0.goal = .loss }, { $0.bcs = 8; edit(&$0) }))
        }
        round2(floor, 132.25)
        round2(try Estimator.weightLossStartKcal(ibwKg: ibw, k: 75, verifiedIntakeKcal: nil, floorKcal: floor), 167.17)
        round2(try Estimator.weightLossStartKcal(ibwKg: ibw, k: 63.5, verifiedIntakeKcal: nil, floorKcal: floor), 141.54)
        round2(try Estimator.weightLossStartKcal(ibwKg: ibw, k: 100, verifiedIntakeKcal: nil, floorKcal: floor), 176.34)
        round2(try Estimator.weightLossStartKcal(ibwKg: ibw, k: 75, verifiedIntakeKcal: 200, floorKcal: floor), 160)
        round2(try Estimator.weightLossStartKcal(ibwKg: ibw, k: 75, verifiedIntakeKcal: 150, floorKcal: floor), 132.25)
        XCTAssertNil(try Estimator.weightLossStartKcal(ibwKg: ibw, k: 75, verifiedIntakeKcal: 120, floorKcal: floor))
        let sedentary = try loss { $0.lifestyle = .sedentary }
        round2(sedentary.startKcal, 141.54); XCTAssertLessThan(sedentary.startKcal!, Estimator.mer(63.5, ibw)); near(sedentary.coefficient, 0.8)
        round2(try loss { $0.lifestyle = .active }.startKcal, 176.34)
        round2(try loss { $0.verifiedIntakeKcal = 200 }.startKcal, 160); round2(try loss { $0.verifiedIntakeKcal = 150 }.startKcal, 132.25)
        let refer = try loss { $0.verifiedIntakeKcal = 120 }
        XCTAssertEqual(refer.status, .refer); XCTAssertEqual(refer.reasons, [.verifiedIntakeBelowFloor])
        XCTAssertNil(refer.startKcal); XCTAssertNil(refer.idealWeight); XCTAssertEqual(refer.notes, [])
    }
    /// SCIENCE.md §12.2 kitten vectors (D4).
    func testKittenVectors() throws {
        func kitten(_ bw: Double, _ years: Double, _ edit: @escaping (inout Profile) -> Void = { _ in }) throws -> EnergyEstimate {
            try estimate(cat({ $0.weightKg = bw }, { $0.approxAgeYears = years; edit(&$0) }))
        }
        near(Estimator.kittenBandMultiplier(1, [2, 1.75, 1.5]), 2); near(Estimator.kittenBandMultiplier(4, [2, 1.75, 1.5]), 2 - 2 / 4.5 * 0.25)
        near(Estimator.kittenBandMultiplier(11, [2.5, 2, 1.5]), 1.5)
        let nrc4 = try kitten(2, 1.0 / 3) { $0.expectedAdultWeightKg = 4; $0.neutered = .no; $0.lifestyle = nil }
        round2(nrc4.startKcal, 266.32); round2(nrc4.lowKcal, 225.40); round2(nrc4.highKcal, 362.41); XCTAssertFalse(nrc4.notes.contains(.kittenTransition))
        round2(try kitten(2, 1.0 / 3) { $0.neutered = .no; $0.lifestyle = nil }.startKcal, 293.91)
        let age = try kitten(3.4, 11.0 / 12) { $0.expectedAdultWeightKg = 4 }
        round2(age.startKcal, 230.85); XCTAssertEqual((age.lowKcal! * 10).rounded() / 10, 144.7); XCTAssertEqual((age.highKcal! * 10).rounded() / 10, 340.6)
        XCTAssertTrue(age.notes.contains(.kittenTransition))
        round2(try kitten(3.4, 11.0 / 12).startKcal, 234.13)
        round2(try kitten(3.6, 0.75) { $0.expectedAdultWeightKg = 4 }.startKcal, 233.54)
        let capped = try kitten(0.8, 2.0 / 12) { $0.expectedAdultWeightKg = 4; $0.neutered = .no; $0.lifestyle = nil }
        round2(capped.startKcal, 148.03); XCTAssertTrue(capped.notes.contains(.clampedHigh))
        let bandCapped = try kitten(1, 2.0 / 12) { $0.neutered = .no; $0.lifestyle = nil }
        near(bandCapped.startKcal, 2.5 * (try Estimator.rer(1))); XCTAssertTrue(bandCapped.notes.contains(.clampedHigh))
    }
    func testExpectedAdultWeightKeepsKittenProtections() throws {
        for months in [2.0, 8, 11.9] { for weight in [4.0, 4.1] { for goal in [Goal.maintain, .loss, .gain] {
            let c = cat({ $0.weightKg = weight; $0.goal = goal }, { $0.approxAgeYears = months / 12; $0.expectedAdultWeightKg = 4; $0.bcs = 8 })
            let e = try estimate(c)
            XCTAssertEqual(try Estimator.stageOf(c, asOf: asOf), .kitten); XCTAssertEqual(e.lifeStageLabel, .kitten)
            XCTAssertEqual(e.status, .refer); XCTAssertEqual(e.reasons, [.kittenAdultWeightReached])
            XCTAssertNil(e.startKcal); XCTAssertNil(e.equation); XCTAssertNil(e.floorKcal)
            let trend = try TrendAnalysis.trend(c, asOf: asOf, estimate: e, series: TrendAnalysis.weightSeries(c, asOf: asOf))
            XCTAssertEqual(trend.nextWeighInDays, 7); XCTAssertNil(trend.suggestion)
            XCTAssertEqual(NutritionChecker.check(c, estimate: e, intake: [], kcal: 0), .notApplicable)
        }}}
        let missing = try estimate(cat({ $0.weightKg = 4.1 }, { $0.approxAgeYears = 8.0 / 12; $0.expectedAdultWeightKg = 4; $0.neutered = .unknown; $0.bcs = nil }))
        XCTAssertEqual(missing.status, .refer); XCTAssertEqual(missing.missing, [])
        var below = cat({ $0.weightKg = 3.9 }, { $0.approxAgeYears = 8.0 / 12; $0.expectedAdultWeightKg = 4 })
        XCTAssertEqual(try estimate(below).equation, .kittenNrc)
        below.profile.approxAgeYears = 1; below.weightKg = 4
        XCTAssertEqual(try Estimator.stageOf(below, asOf: asOf), .adult); XCTAssertEqual(try estimate(below).status, .ok)
        let stalled = cat({ $0.weightLog = entries([(-7, 4), (0, 4)]) }, { $0.approxAgeYears = 8.0 / 12; $0.expectedAdultWeightKg = 4 })
        XCTAssertEqual(try TrendAnalysis.stops(stalled, series: TrendAnalysis.weightSeries(stalled, asOf: asOf), stage: Estimator.stageOf(stalled, asOf: asOf)), [.kittenNotGrowing])
    }
    /// D2: W is the ideal weight whenever it is below the current weight.
    func testWeightUsedIsIdealWeightBelowCurrent() throws {
        let vet = try estimate(cat({ $0.weightKg = 5 }, { $0.idealWeightKg = 4.5; $0.idealWeightSource = .veterinarian }))
        near(vet.weightUsedKg, 4.5); near(vet.startKcal, Estimator.mer(75, 4.5)); XCTAssertEqual((vet.startKcal! * 10).rounded() / 10, 205.5)
        near(try estimate(cat({ $0.weightKg = 5; $0.goal = .gain }, { $0.bcs = 4; $0.idealWeightKg = 4.8; $0.idealWeightSource = .veterinarian })).startKcal,
             1.15 * Estimator.mer(75, 4.8))
        near(try estimate(cat({ _ in }, { $0.idealWeightKg = 4.5; $0.idealWeightSource = .veterinarian })).weightUsedKg, 4)
    }
    func testFoodAnchors() {
        near(FoodAnalysis.meKcalPer100g(wet), 99.2455); round2(FoodAnalysis.meKcalPer100g(wet), 99.25)
        near(FoodAnalysis.atwaterKcalPer100g(wet), 93.25)
        XCTAssertEqual(String(format: "%.1f", FoodAnalysis.meKcalPer100g(dry)), "379.5"); near(FoodAnalysis.atwaterKcalPer100g(dry), 357)
        near(FoodAnalysis.nfe(wet), 4.5); near(FoodAnalysis.nfe(dry), 34)
    }
    func testFreshFoodAndAssumedMoisture() {
        near(FoodAnalysis.meKcalPer100g(Analysis(protein: 18, fat: 9, fibre: 0.5, ash: 1.5, moisture: 70, kind: .fresh)), 152.5)
        var assumed = dry; assumed.moisture = nil
        near(FoodAnalysis.meKcalPer100g(assumed), FoodAnalysis.meKcalPer100g(dry))
        let food = Food(id: "d", name: "D", type: .dry, energyPerUnit: 380, energyUnit: .kcalPer100g, energySource: .label, completeness: .complete, lifeStageClaim: .adult, analysis: assumed)
        let r = FoodAnalysis.analyse(food)
        XCTAssertEqual(r?.warnings, [.assumedMoisture]); XCTAssertEqual(r?.moisture, 8); XCTAssertEqual(r?.method, .fediaf4Step)
    }
    func testFoodAnalysisDerivedValuesAndWarnings() throws {
        let food = Food(id: "w", name: "W", type: .wet, energyPerUnit: 60, energyUnit: .kcalPer100g, energySource: .label, completeness: .complete, lifeStageClaim: .all, analysis: wet)
        let r = try XCTUnwrap(FoodAnalysis.analyse(food)), me = FoodAnalysis.meKcalPer100g(wet)
        XCTAssertEqual(r.warnings, [.labelEnergyMismatch])
        near(r.dryMatter.protein, 10 / 22 * 100); near(r.proteinGPer1000kcal, 10 / me * 1000); near(r.fatGPer1000kcal, 5 / me * 1000)
        near(r.carbGPer100kcal, 4.5 / me * 100)
        near(r.energySharePercent.protein + r.energySharePercent.fat + r.energySharePercent.carbohydrate, 100)
        var f = food; f.energyPerUnit = 99
        XCTAssertEqual(FoodAnalysis.analyse(f)?.warnings, [])
        f = food; f.energySource = .analysis; f.energyPerUnit = nil
        XCTAssertEqual(FoodAnalysis.analyse(f)?.warnings, [])
        near(try CalorieCalculator.kcalPerGram(f), me / 100)
        f = food; f.energyPerUnit = 97; f.analysis = Analysis(protein: 20, fat: 2, fibre: 0, ash: 3, moisture: 75, kind: .fresh)
        XCTAssertEqual(FoodAnalysis.analyse(f)?.warnings, [.atwaterDisagreement])
        f = food; f.analysis = nil
        XCTAssertNil(FoodAnalysis.analyse(f))
        near(try CalorieCalculator.kcalPerGram(food), 0.6)
    }
    func testStatusPrecedenceAndNullFields() throws {
        let refer = try estimate(cat({ _ in }, { $0.bcs = 3; $0.neutered = .unknown }))
        XCTAssertEqual(refer.status, .refer); XCTAssertEqual(refer.reasons, [.bcsLow]); XCTAssertEqual(refer.missing, [.neutered])
        XCTAssertNil(refer.startKcal); XCTAssertNil(refer.lowKcal); XCTAssertNil(refer.highKcal); XCTAssertNil(refer.floorKcal)
        XCTAssertNil(refer.referenceBand); XCTAssertNil(refer.comparison); XCTAssertNil(refer.equation)
        near(refer.rerKcal, try Estimator.rer(4))
        let needs = try estimate(cat({ _ in }, { $0.bcs = nil }))
        XCTAssertEqual(needs.status, .needsInput); XCTAssertEqual(needs.missing, [.bcs]); XCTAssertNil(needs.startKcal)
        let stop = try estimate(cat(), [.rapidWeightChange])
        XCTAssertEqual(stop.status, .refer); XCTAssertEqual(stop.reasons, [.rapidWeightChange])
    }
    func testStageLabelAndAge() throws {
        func at(_ edit: (inout Profile) -> Void) throws -> EnergyEstimate { try estimate(cat({ _ in }, { $0.approxAgeYears = nil; edit(&$0) })) }
        XCTAssertEqual(try at { $0.birthDate = "2016-10-09" }.stage, .adult)
        XCTAssertEqual(try at { $0.birthDate = "2016-10-09" }.lifeStageLabel, .matureAdult)
        XCTAssertEqual(try at { $0.birthDate = "2015-10-08" }.stage, .senior)
        XCTAssertEqual(try at { $0.approxAgeYears = 2 }.lifeStageLabel, .youngAdult)
        XCTAssertEqual(try at { $0.birthDate = "2027-01-01" }.missing, [.age])
        near(try Estimator.ageInDays(cat({ _ in }, { $0.approxAgeYears = 2 }).profile, asOf: asOf), 730.5)
        XCTAssertEqual(try Estimator.stageOf(cat({ _ in }, { $0.approxAgeYears = 0.1 }), asOf: asOf), .neonate)
        XCTAssertEqual(try Estimator.stageOf(cat({ _ in }, { $0.endOfLife = true }), asOf: asOf), .endOfLife)
    }
    func testIdealWeight() {
        XCTAssertEqual(Estimator.idealWeightOf(cat({ _ in }, { $0.idealWeightKg = 3.5 }), bcs: 8), IdealWeight(kg: 3.5, lowKg: 3.5, highKg: 3.5, source: .veterinarian))
        let bcs = Estimator.idealWeightOf(cat({ $0.weightKg = 6 }), bcs: 8)
        near(bcs.kg, 6 / 1.3); near(bcs.lowKg, 6 / 1.3 * 0.9); XCTAssertEqual(bcs.source, .bcsEstimate)
        XCTAssertEqual(Estimator.idealWeightOf(cat(), bcs: 5).source, .current)
        let stored = Estimator.idealWeightOf(cat({ $0.weightKg = 5.4 }, { $0.idealWeightKg = 4.6; $0.idealWeightSource = .estimate }), bcs: 6)
        XCTAssertEqual(stored.source, .estimate); near(stored.kg, 4.6); near(stored.lowKg, 4.6 * 0.9); near(stored.highKg, 4.6 * 1.1)
    }
    func testEffectiveBcs() throws {
        var c = cat({ $0.weightLog = [WeightEntry(id: "a", date: day(-9), weightKg: 4, bcs: 7), WeightEntry(id: "b", date: day(-3), weightKg: 4),
                                      WeightEntry(id: "c", date: day(10), weightKg: 4, bcs: 2)] })
        XCTAssertEqual(try Estimator.effectiveBcs(c, asOf: asOf), 5)
        c.profile.bcs = nil; XCTAssertEqual(try Estimator.effectiveBcs(c, asOf: asOf), 7)
        c.weightLog[0].bcs = nil; XCTAssertNil(try Estimator.effectiveBcs(c, asOf: asOf))
    }
    func testFloorClampsComparisonAndRecentNeuter() throws {
        let loss = try estimate(cat({ $0.weightKg = 6; $0.goal = .loss; $0.targetKcal = 110 }, { $0.bcs = 8 }))
        near(loss.floorKcal, 0.6 * (try Estimator.rer(6 / 1.3))); XCTAssertGreaterThanOrEqual(loss.lowKcal!, loss.floorKcal!)
        XCTAssertEqual(loss.comparison?.belowFloor, true); XCTAssertEqual(loss.comparison?.differsOver30Percent, true); XCTAssertEqual(loss.comparison?.belowRange, true)
        let clamped = try estimate(cat({ $0.weightKg = 1 }, { $0.lifestyle = .active }))
        near(clamped.startKcal, 1.4 * (try Estimator.rer(1))); XCTAssertTrue(clamped.notes.contains(.clampedHigh))
        let neutered = cat({ _ in }, { $0.neuteredDate = day(-182) })
        XCTAssertTrue(try estimate(neutered).notes.contains(.recentlyNeutered))
        let series = try TrendAnalysis.weightSeries(neutered, asOf: asOf)
        XCTAssertEqual(try TrendAnalysis.trend(neutered, asOf: asOf, estimate: estimate(neutered), series: series).nextWeighInDays, 14)
        XCTAssertFalse(try estimate(cat({ _ in }, { $0.neuteredDate = day(-183) })).notes.contains(.recentlyNeutered))
    }
    func testChronicFlagsGiveReferenceOnly() throws {
        let e = try estimate(cat({ $0.weightKg = 5; $0.goal = .loss }, { $0.bcs = 8; $0.medical = [.diabetes] }))
        XCTAssertEqual(e.status, .referenceOnly); XCTAssertEqual(e.equation, .adultFediaf); near(e.startKcal, Estimator.mer(75, 5))
        XCTAssertEqual(e.notes, [.diabetesLowCarbInfo, .medicalVetPlan])
    }
    func testWeightSeriesRateAndWindow() throws {
        let c = cat({ $0.weightLog = [WeightEntry(id: "old", date: day(-60), weightKg: 3), WeightEntry(id: "a", date: day(-28), weightKg: 4),
            WeightEntry(id: "b", date: day(-14), weightKg: 3.9), WeightEntry(id: "c", date: day(0), weightKg: 3.85), WeightEntry(id: "future", date: day(1), weightKg: 9)] })
        let s = try TrendAnalysis.weightSeries(c, asOf: asOf)
        XCTAssertEqual(s.entries.count, 4); XCTAssertEqual(s.window.count, 3); XCTAssertEqual(s.spanDays, 28)
        let ys = [4, 3.9, 3.85], my = ys.reduce(0, +) / 3
        let slope = ([0.0, 14, 28].enumerated().reduce(0) { $0 + ($1.element - 14) * (ys[$1.offset] - my) }) / (14 * 14 * 2)
        near(s.ratePercentPerWeek, slope * 7 / my * 100); near(s.change28dPercent, -3.75)
        XCTAssertEqual(try TrendAnalysis.stops(c, series: s, stage: .adult), [])
        let short = try TrendAnalysis.weightSeries(cat({ $0.weightLog = entries([(-6, 4), (0, 4.1)]) }), asOf: asOf)
        XCTAssertNil(short.ratePercentPerWeek); XCTAssertNil(short.change28dPercent)
    }
    func testTrendStops() throws {
        func stops(_ c: Cat) throws -> [ReferCode] {
            try TrendAnalysis.stops(c, series: TrendAnalysis.weightSeries(c, asOf: asOf), stage: Estimator.stageOf(c, asOf: asOf))
        }
        func log(_ a: Double, _ b: Double, _ days: Int = 21) -> [WeightEntry] { entries([(-days, a), (0, b)]) }
        XCTAssertEqual(try stops(cat({ $0.weightLog = log(4, 4.2) })), [.rapidWeightChange])
        XCTAssertEqual(try stops(cat({ $0.weightLog = log(4, 3.8) })), [.rapidWeightChange])
        XCTAssertEqual(try stops(cat({ $0.goal = .loss; $0.weightLog = log(4, 3.8) })), [])
        XCTAssertEqual(try stops(cat({ $0.goal = .loss; $0.weightLog = log(4, 4.2) })), [.rapidWeightChange])
        // D5: on a weight-loss plan, faster than 3 %/week or 8 % in 28 days stops the plan.
        XCTAssertEqual(try stops(cat({ $0.goal = .loss; $0.weightLog = log(6, 5.6, 14) })), [.rapidWeightChange])
        XCTAssertEqual(try stops(cat({ $0.goal = .loss; $0.weightLog = log(6, 5.7, 14) })), [])
        let slowLarge = cat({ $0.goal = .loss; $0.weightLog = entries([(-28, 6), (-14, 5.6), (0, 5.5)]) })
        XCTAssertGreaterThan(try TrendAnalysis.weightSeries(slowLarge, asOf: asOf).ratePercentPerWeek!, -3)
        XCTAssertEqual(try stops(slowLarge), [.rapidWeightChange])
        XCTAssertEqual(try stops(cat({ $0.goal = .gain; $0.weightLog = log(4, 3.81, 14) })), [.rapidWeightChange])
        func kitten(_ w: Double) -> Cat { cat({ $0.weightKg = 1.5; $0.weightLog = log(1.5, w, 7) }, { $0.approxAgeYears = 0.3 }) }
        XCTAssertEqual(try stops(kitten(1.5)), [.kittenNotGrowing]); XCTAssertEqual(try stops(kitten(1.6)), [])
        XCTAssertEqual(try stops(cat({ $0.weightKg = 1.5; $0.weightLog = log(1.5, 1.5, 15) }, { $0.approxAgeYears = 0.3 })), [])
        XCTAssertEqual(try stops(cat({ $0.weightKg = 2; $0.weightLog = log(1.5, 2) }, { $0.approxAgeYears = 0.3 })), [])
    }
    func testSuggestions() throws {
        func run(_ c: Cat) throws -> Trend {
            let s = try TrendAnalysis.weightSeries(c, asOf: asOf)
            let e = try estimate(c, TrendAnalysis.stops(c, series: s, stage: Estimator.stageOf(c, asOf: asOf)))
            return try TrendAnalysis.trend(c, asOf: asOf, estimate: e, series: s)
        }
        func loss(_ target: Double, _ log: [(Int, Double)]) -> Cat { cat({ $0.weightKg = 6; $0.goal = .loss; $0.targetKcal = target; $0.weightLog = entries(log) }, { $0.bcs = 8 }) }
        XCTAssertEqual(try run(loss(200, [(-14, 6), (0, 5.7)])).suggestion, Suggestion(action: .increase, reason: .lossTooFast, suggestedKcal: 200 * 1.1))
        XCTAssertEqual(try run(loss(200, [(-28, 6), (-14, 6), (0, 6)])).suggestion, Suggestion(action: .decrease, reason: .plateau, suggestedKcal: 180))
        XCTAssertEqual(try run(loss(140, [(-28, 6), (-14, 6), (0, 6)])).suggestion, Suggestion(action: .refer, reason: .atFloor, suggestedKcal: nil))
        XCTAssertEqual(try run(loss(200, [(-21, 6), (-7, 6), (0, 6)])).suggestion, Suggestion(action: .decrease, reason: .plateau, suggestedKcal: 180))
        XCTAssertEqual(try run(loss(200, [(-20, 6), (-6, 6), (0, 6)])).suggestion?.action, .hold)
        func gain(_ log: [(Int, Double)]) -> Cat { cat({ $0.goal = .gain; $0.targetKcal = 230; $0.weightLog = entries(log) }, { $0.bcs = 4 }) }
        XCTAssertEqual(try run(gain([(-21, 4), (-7, 4), (0, 3.99)])).suggestion?.reason, .notGaining)
        XCTAssertEqual(try run(gain([(-20, 4), (-6, 4), (0, 3.99)])).suggestion?.reason, .onTrack)
        XCTAssertEqual(try run(loss(200, [(-14, 6), (0, 6)])).suggestion?.action, .hold)
        XCTAssertEqual(try run(loss(200, [(-14, 6), (0, 6)])).nextWeighInDays, 14)
        XCTAssertNil(try run(cat({ $0.weightLog = entries([(-14, 4), (0, 4.01)]) }, { $0.bcs = nil })).suggestion)
        XCTAssertNil(try run(cat()).suggestion)
        XCTAssertEqual(try run(cat()).nextWeighInDays, 28)
        XCTAssertEqual(try run(gain([(-14, 4), (0, 4)])).nextWeighInDays, 14)
        // D8: a cat weighed exactly on the default cadence must still get a 28-day change and a rate (the window is inclusive).
        let onCadence = try run(cat({ $0.weightLog = entries([(-28, 4), (0, 4.12)]) }))
        XCTAssertNotNil(onCadence.change28dPercent); XCTAssertNotNil(onCadence.ratePercentPerWeek)
        XCTAssertEqual(onCadence.suggestion?.reason, .gaining)
        let kitten = try run(cat({ $0.weightKg = 2; $0.weightLog = entries([(-14, 1.8), (0, 2)]) }, { $0.approxAgeYears = 0.3 }))
        XCTAssertNil(kitten.suggestion); XCTAssertEqual(kitten.nextWeighInDays, 7)
        XCTAssertEqual(try run(cat({ $0.weightLog = entries([(-28, 4), (0, 4.12)]) })).suggestion?.reason, .gaining)
        XCTAssertEqual(try run(cat({ $0.goal = .gain }, { $0.bcs = 4 })).suggestion, nil)
    }
    func testNutritionChecks() throws {
        func food(_ id: String, _ analysis: Analysis?, _ claim: LifeStageClaim = .adult) -> Food {
            Food(id: id, name: id, type: .dry, energyPerUnit: 380, energyUnit: .kcalPer100g, energySource: .label, completeness: .complete, lifeStageClaim: claim, analysis: analysis)
        }
        func intake(_ f: Food, _ grams: Double) -> NutritionChecker.FoodIntake { .init(food: f, grams: grams) }
        let c = cat({ $0.goal = .loss; $0.weightKg = 6 }, { $0.bcs = 8; $0.medical = [.diabetes] })
        let e = try estimate(cat({ $0.weightKg = 6; $0.goal = .loss }, { $0.bcs = 8 }))
        guard case .ok(let r) = NutritionChecker.check(c, estimate: e, intake: [intake(food("d", dry), 50)], kcal: 190) else { return XCTFail() }
        near(r.proteinG, 17); near(r.proteinPer1000, 17 / 190 * 1000)
        near(r.minProteinPer1000, max(62.5, 6250 / (190 / pow(e.weightUsedKg!, 0.67)))); near(r.carbPercentME, 3.5 * 34 / 357 * 100); XCTAssertEqual(r.notes, [])
        XCTAssertEqual(r.warnings, [.carbAboveDiabeticThreshold, .proteinBelow5gPerKgIbw, .proteinBelowMinimum])
        let kittenEstimate = try estimate(cat({ _ in }, { $0.approxAgeYears = 0.4 }))
        guard case .ok(let k) = NutritionChecker.check(cat(), estimate: kittenEstimate, intake: [intake(food("d", dry), 50)], kcal: 190) else { return XCTFail() }
        XCTAssertEqual(k.minProteinPer1000, 70); XCTAssertEqual(k.warnings, [.growthClaimMissing])
        let queen = try estimate(cat({ _ in }, { $0.approxAgeYears = 3; $0.reproduction = Reproduction(status: .gestation) }))
        guard case .ok(let q) = NutritionChecker.check(cat(), estimate: queen, intake: [intake(food("d", dry, .growth), 50)], kcal: 190) else { return XCTFail() }
        XCTAssertEqual(q.minProteinPer1000, 75)
        guard case .ok(let g) = NutritionChecker.check(cat(), estimate: kittenEstimate, intake: [intake(food("d", dry, .growth), 50)], kcal: 190) else { return XCTFail() }
        XCTAssertEqual(g.warnings, [])
        XCTAssertEqual(NutritionChecker.check(cat(), estimate: e, intake: [intake(food("x", nil), 5), intake(food("d", dry), 50), intake(food("y", nil), 0)], kcal: 190),
                       .incompleteData(missingFoodIds: ["x"]))
    }
    /// D6: Atwater carbohydrate basis, CKD suppression, the weight-loss equation only, not applicable for unusable estimates.
    func testNutritionRevision() throws {
        func food(_ id: String, _ analysis: Analysis?, _ energy: Double) -> Food {
            Food(id: id, name: id, type: .wet, energyPerUnit: energy, energyUnit: .kcalPer100g, energySource: .label, completeness: .complete, lifeStageClaim: .adult, analysis: analysis)
        }
        func check(_ c: Cat, _ e: EnergyEstimate, _ items: [(Food, Double)], _ kcal: Double) -> NutritionResult {
            NutritionChecker.check(c, estimate: e, intake: items.map { .init(food: $0.0, grams: $0.1) }, kcal: kcal)
        }
        let e = try estimate(cat()), wetFood = food("w", wet, 100), dryFood = food("d", dry, 380)
        guard case .ok(let w) = check(cat(), e, [(wetFood, 100)], 100), case .ok(let d) = check(cat(), e, [(dryFood, 100)], 380),
              case .ok(let mixed) = check(cat(), e, [(wetFood, 100), (dryFood, 30)], 214) else { return XCTFail() }
        round2(w.carbPercentME, 16.89); round2(d.carbPercentME, 33.33); round2(mixed.carbPercentME, 25.68)
        let ckdCat = cat({ $0.weightKg = 5 }, { $0.medical = [.ckd] })
        guard case .ok(let ckd) = check(ckdCat, try estimate(ckdCat), [(dryFood, 39)], 148.2) else { return XCTFail() }
        XCTAssertLessThan(ckd.proteinPer1000, ckd.minProteinPer1000); XCTAssertEqual(ckd.warnings, []); XCTAssertEqual(ckd.notes, [.ckdProteinVet])
        let notIndicated = cat({ $0.goal = .loss }), ni = try estimate(notIndicated)
        XCTAssertEqual(ni.equation, .adultFediaf)
        guard case .ok(let n) = check(notIndicated, ni, [(wetFood, 190)], 190) else { return XCTFail() }
        XCTAssertEqual(n.warnings, [])
        XCTAssertEqual(check(cat(), try estimate(cat({ _ in }, { $0.bcs = nil })), [(wetFood, 100)], 100), .notApplicable)
        XCTAssertEqual(check(cat(), try estimate(cat({ _ in }, { $0.bcs = 3 })), [(food("x", nil, 100), 100)], 100), .notApplicable)
    }
    func testNutritionUsesRoundedBalanceGramsAndFoodEnergyOnly() throws {
        let plan = Plan(name: "N", foods: [Food(id: "dry", name: "Dry", type: .dry, energyPerUnit: 380, energyUnit: .kcalPer100g, energySource: .label, completeness: .complete, lifeStageClaim: .adult, analysis: dry)],
                        cats: [cat({ $0.extraKcal = 10 })], activities: [Activity(id: "a", label: "A", sharePercent: 100)])
        let r = try CalorieCalculator.calculate(plan, asOf: asOf).cats[0]
        guard case .ok(let n) = r.nutrition else { return XCTFail() }
        near(n.kcal, Double(r.balanceGramsRounded) * 3.8); near(n.proteinG, Double(r.balanceGramsRounded) * 0.34)
    }
    func testDatesAreStrictCalendarDates() throws {
        for ok in ["2024-02-29", "2026-10-09", "1999-12-31"] { XCTAssertTrue(Dates.isISODate(ok), ok) }
        for bad in ["2023-02-29", "2026-13-01", "2026-1-01", "2026-10-09T00:00:00Z", " 2026-10-09", "", "2026-10-09\n", "0050-01-01", "2026-00-10"] {
            XCTAssertFalse(Dates.isISODate(bad), bad)
        }
        XCTAssertEqual(try Dates.daysBetween("2026-03-28", "2026-03-30"), 2)
        XCTAssertEqual(try Dates.daysBetween("1970-01-01", "2026-10-09"), 20_735)
        XCTAssertEqual(try Dates.daysBetween("2026-10-09", "2020-02-29"), -2414)
        XCTAssertThrowsError(try Dates.daysBetween("x", asOf))
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        XCTAssertEqual(Dates.todayLocal(calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 23, minute: 59))!), "2026-01-05")
    }
    func testMessagesAndModel() {
        XCTAssertEqual(Set(Messages.de.keys), Set(Messages.en.keys))
        let codes: [String: [String]] = [
            "warning": WarningCode.allCases.map(\.rawValue), "refer": ReferCode.allCases.map(\.rawValue), "missing": InputCode.allCases.map(\.rawValue),
            "note": NoteCode.allCases.map(\.rawValue), "food": FoodWarningCode.allCases.map(\.rawValue),
            "nutrition": ["ok", "incomplete-data", "not-applicable"] + NutritionWarningCode.allCases.map(\.rawValue) + NutritionNoteCode.allCases.map(\.rawValue),
            "idealWeight": IdealWeightSource.allCases.map(\.rawValue), "icon": CatIcon.allCases.map(\.rawValue),
            "action": SuggestionAction.allCases.map(\.rawValue), "status": EstimateStatus.allCases.map(\.rawValue),
            "equation": EquationId.allCases.map(\.rawValue)]
        for (prefix, list) in codes.sorted(by: { $0.key < $1.key }) { for code in list { for locale in ["en", "de"] {
            let key = "\(prefix).\(code)"
            XCTAssertNotNil((locale == "en" ? Messages.en : Messages.de)[key], "\(locale) \(key)")
            XCTAssertNotEqual(Messages.message(key, locale: locale), key)
        } } }
        XCTAssertTrue(Messages.message("warning.unknown-completeness", locale: "de-DE").contains("Alleinfuttermittel"))
        XCTAssertEqual(Messages.message("nope", locale: "fr"), "nope")
        XCTAssertEqual(EnergyModel.version, 2)
        for id in ["adult-fediaf", "weight-loss-aaha", "adult-gain", "kitten-nrc", "kitten-fediaf-band", "gestation-fediaf", "lactation-fediaf"] {
            XCTAssertFalse(EnergyModel.references[id]?.isEmpty ?? true, id)
        }
    }
}
