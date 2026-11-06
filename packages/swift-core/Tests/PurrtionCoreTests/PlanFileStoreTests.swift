import Foundation
import XCTest
@testable import PurrtionCore

/// The data-protecting file rules (audit B-4). Every test works in its own temporary `…/<UUID>/Purrtion` folder, never a real path.
final class PlanFileStoreTests: XCTestCase {
    private var root: URL!
    private var directory: URL!
    /// `$TMPDIR` when set (it is what sandboxed runs may write to), otherwise the system temporary directory.
    private let base = ProcessInfo.processInfo.environment["TMPDIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        root = base.appendingPathComponent("purrtion-tests-\(UUID().uuidString)", isDirectory: true)
        // The name must be "Purrtion": the backup-pruning guard only works inside the app's own folder.
        directory = root.appendingPathComponent("Purrtion", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        // Removes only this test's own temporary folder (created above under the system temp directory).
        guard let root, root.deletingLastPathComponent().standardizedFileURL.path == base.standardizedFileURL.path, root.lastPathComponent.hasPrefix("purrtion-tests-") else { return }
        try? FileManager.default.removeItem(at: root)
    }
    private var plan: URL { directory.appendingPathComponent("plan.json") }
    private func files() throws -> [String] { try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted() }

    func testNoFileStartsFromTheSampleAndSaves() throws {
        let sample = try PlanCodec.sample()
        let store = PlanFileStore(directory: directory, sample: sample)
        XCTAssertFalse(store.recoveryMode); XCTAssertNil(store.storageIssue); XCTAssertEqual(store.plan, sample)
        try store.save(sample)
        XCTAssertEqual(try PlanFileStore.readPlan(at: plan), sample)
    }
    func testDamagedFileIsNeverOverwrittenBySave() throws {
        try Data("{".utf8).write(to: plan)
        let store = PlanFileStore(directory: directory, sample: try PlanCodec.sample())
        XCTAssertTrue(store.recoveryMode); XCTAssertEqual(store.storageIssue, .recovery)
        var edited = store.plan; edited.name = "Edited"
        try store.save(edited)
        XCTAssertEqual(store.plan.name, "Edited", "kept in memory")
        XCTAssertEqual(try Data(contentsOf: plan), Data("{".utf8), "damaged bytes untouched")
        XCTAssertEqual(store.storageIssue, .recovery)
    }
    func testReplaceBacksUpDamagedDataThenWrites() throws {
        try Data("{".utf8).write(to: plan)
        let store = PlanFileStore(directory: directory, sample: try PlanCodec.sample())
        let sample = try PlanCodec.sample()
        try store.replace(sample)
        XCTAssertFalse(store.recoveryMode); XCTAssertNil(store.storageIssue)
        XCTAssertEqual(try PlanFileStore.readPlan(at: plan), sample)
        let backups = try files().filter { $0.hasPrefix("plan-backup-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(backups[0])), Data("{".utf8))
    }
    func testV1FileIsCopiedOnceBeforeTheFirstWrite() throws {
        let v1 = Data("""
        {"schemaVersion":1,"name":"Old","foods":[{"id":"dry","name":"Dry","type":"dry","energyPerUnit":380,"energyUnit":"kcal/100g",
        "energySource":"label","completeness":"complete","note":""}],"cats":[{"id":"c","name":"Cat","weightKg":4,"goal":"maintain",
        "targetKcal":200,"targetSource":"owner","extraKcal":0,"dryFoodId":"dry","meals":[]}],"activities":[{"id":"a","label":"All","sharePercent":100}]}
        """.utf8)
        try v1.write(to: plan)
        let store = PlanFileStore(directory: directory, sample: try PlanCodec.sample())
        XCTAssertFalse(store.recoveryMode); XCTAssertEqual(store.plan.schemaVersion, 2); XCTAssertEqual(store.plan.name, "Old")
        try store.save(store.plan)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("plan-v1-backup.json")), v1)
        try store.save(store.plan)
        XCTAssertEqual(try files().filter { $0.hasPrefix("plan-v1-backup") }, ["plan-v1-backup.json"], "only one copy")
        XCTAssertEqual(try PlanFileStore.readPlan(at: plan).name, "Old")
    }
    func testReplaceKeepsOnlyTheNewestBackups() throws {
        let store = PlanFileStore(directory: directory, sample: try PlanCodec.sample())
        try store.save(store.plan)
        for n in 0..<7 { var next = store.plan; next.name = "Plan \(n)"; try store.replace(next) }
        XCTAssertEqual(try files().filter { $0.hasPrefix("plan-backup-") }.count, PlanFileStore.maximumBackups)
        XCTAssertEqual(store.plan.name, "Plan 6")
    }
    func testFailedWriteKeepsThePlanAndReportsIt() throws {
        let store = PlanFileStore(directory: directory, sample: try PlanCodec.sample())
        // A directory where plan.json should be makes the atomic write fail.
        try FileManager.default.createDirectory(at: plan, withIntermediateDirectories: false)
        var edited = store.plan; edited.name = "Edited"
        try store.save(edited)
        XCTAssertEqual(store.plan.name, "Edited")
        guard case .saveFailed = store.storageIssue else { return XCTFail("expected saveFailed, got \(String(describing: store.storageIssue))") }
    }
}
