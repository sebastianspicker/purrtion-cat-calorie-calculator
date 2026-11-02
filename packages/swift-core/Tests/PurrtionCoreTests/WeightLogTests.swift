import XCTest
@testable import PurrtionCore

final class WeightLogTests: XCTestCase {
    private func cat() throws -> Cat {
        var c = try PlanCodec.sample().cats[0]
        c.weightLog = []; c.weightKg = 4; c.profile.bcs = 5
        return c
    }
    func testAddNewestSetsWeightAndBcs() throws {
        var c = try cat()
        c.addWeighIn(id: "a", date: "2026-10-01", weightKg: 4.2, bcs: 6)
        XCTAssertEqual(c.weightKg, 4.2); XCTAssertEqual(c.profile.bcs, 6)
    }
    func testAddOlderDoesNotChangeWeight() throws {
        var c = try cat()
        c.addWeighIn(id: "a", date: "2026-10-01", weightKg: 4.2, bcs: 6)
        c.addWeighIn(id: "b", date: "2026-09-01", weightKg: 3.9, bcs: 4)
        XCTAssertEqual(c.weightKg, 4.2); XCTAssertEqual(c.profile.bcs, 6); XCTAssertEqual(c.weightLog.count, 2)
    }
    func testSameDateReplaces() throws {
        var c = try cat()
        c.addWeighIn(id: "a", date: "2026-10-01", weightKg: 4.2, bcs: nil)
        c.addWeighIn(id: "b", date: "2026-10-01", weightKg: 4.3, bcs: nil)
        XCTAssertEqual(c.weightLog.map(\.id), ["b"]); XCTAssertEqual(c.weightKg, 4.3); XCTAssertEqual(c.profile.bcs, 5)
    }
    func testRemoveNewestRestoresPreviousWeightWithoutBcs() throws {
        var c = try cat()
        c.addWeighIn(id: "a", date: "2026-09-01", weightKg: 3.9, bcs: nil)
        c.addWeighIn(id: "b", date: "2026-10-01", weightKg: 4.2, bcs: 7)
        c.removeWeighIn(id: "b")
        XCTAssertEqual(c.weightKg, 3.9); XCTAssertEqual(c.profile.bcs, 7) // the earlier entry has no BCS, so the BCS stays
    }
    func testRemoveNewestRestoresBcsWhenPresent() throws {
        var c = try cat()
        c.addWeighIn(id: "a", date: "2026-09-01", weightKg: 3.9, bcs: 4)
        c.addWeighIn(id: "b", date: "2026-10-01", weightKg: 4.2, bcs: 7)
        c.removeWeighIn(id: "b")
        XCTAssertEqual(c.weightKg, 3.9); XCTAssertEqual(c.profile.bcs, 4)
    }
    func testRemoveOlderChangesNothing() throws {
        var c = try cat()
        c.addWeighIn(id: "a", date: "2026-09-01", weightKg: 3.9, bcs: 4)
        c.addWeighIn(id: "b", date: "2026-10-01", weightKg: 4.2, bcs: 7)
        c.removeWeighIn(id: "a")
        XCTAssertEqual(c.weightKg, 4.2); XCTAssertEqual(c.profile.bcs, 7)
    }
    func testRemoveLastKeepsWeight() throws {
        var c = try cat()
        c.addWeighIn(id: "a", date: "2026-10-01", weightKg: 4.2, bcs: nil)
        c.removeWeighIn(id: "a")
        XCTAssertEqual(c.weightKg, 4.2); XCTAssertTrue(c.weightLog.isEmpty)
    }
}
