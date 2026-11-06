import Foundation
import Observation
import PurrtionCore

enum ExportKind { case json, csv }

/// Lets the sidebar ask an open editor whether it has unsaved edits and have it save them.
/// Deliberately not observable: it is read only at the moment the selection changes.
@MainActor
final class UnsavedChanges {
    private(set) var hasChanges = false
    private var owner: String?
    private var saveAction: (() -> Bool)?
    func register(owner: String, hasChanges: Bool, save: @escaping () -> Bool) {
        self.owner = owner; self.hasChanges = hasChanges; saveAction = save
    }
    /// Called when an editor goes away; ignored if another editor has registered since.
    func release(_ owner: String) {
        guard self.owner == owner else { return }
        self.owner = nil; hasChanges = false; saveAction = nil
    }
    func discard() { hasChanges = false }
    /// Saves the open editor's draft; true when nothing is left unsaved.
    func save() -> Bool { saveAction?() ?? true }
}

@MainActor
@Observable
final class PlanStore {
    let unsaved = UnsavedChanges()
    /// The file rules (recovery mode, v1 copy, backups) live in `PurrtionCore.PlanFileStore`, where they are tested.
    /// Its state is copied into the observed properties below after every call.
    private let files: PlanFileStore
    private(set) var plan: Plan
    /// Increments when the whole plan is replaced (import, reset), so open editors reload their drafts.
    private(set) var loadToken = 0
    private(set) var recoveryMode: Bool
    private(set) var storageIssue: StorageIssue?
    var errorMessage: String?
    var showImport = false
    var showExport = false
    var exportKind: ExportKind = .json
    var exportText = ""
    var storageURL: URL { files.storageURL }

    init() {
        // A bad bundled seed is a developer/build error; it is covered by unit tests.
        let sample: Plan
        do { sample = try PlanCodec.sample() }
        catch { preconditionFailure("Invalid bundled sample: \(error.localizedDescription)") }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        files = PlanFileStore(directory: support.appendingPathComponent("Purrtion", isDirectory: true), sample: sample)
        plan = files.plan; recoveryMode = files.recoveryMode; storageIssue = files.storageIssue
    }
    private func sync() { plan = files.plan; recoveryMode = files.recoveryMode; storageIssue = files.storageIssue }

    /// Today's local date; every calculation uses it as `asOf`.
    var asOf: String { Dates.todayLocal() }

    func calculate(_ candidate: Plan) -> PlanResult? { try? CalorieCalculator.calculate(candidate, asOf: asOf) }
    var result: PlanResult? { calculate(plan) }

    /// Keeps the plan; a failed write sets `storageIssue` instead of throwing (see `PlanFileStore.save`).
    func save(_ candidate: Plan) throws { defer { sync() }; try files.save(candidate) }
    func replace(_ candidate: Plan) throws {
        defer { sync() }
        try files.replace(candidate)
        loadToken += 1
    }
    func reset() throws { try replace(PlanCodec.sample()) }

    func prepareExport(_ kind: ExportKind) {
        do {
            switch kind {
            case .json: exportText = String(decoding: try PlanCodec.encode(plan), as: UTF8.self)
            case .csv: exportText = try PlanCodec.csv(plan, asOf: asOf)
            }
            exportKind = kind; showExport = true
        } catch { errorMessage = error.localizedDescription }
    }
}
