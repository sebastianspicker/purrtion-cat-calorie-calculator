import Foundation
import Observation
import PurrtionCore

enum ExportKind { case json, csv }

/// Problems with the local file; the views localise them.
enum StorageIssue: Equatable {
    /// The saved file could not be read and has not been overwritten.
    case recovery
    /// Changes are in memory but could not be written.
    case saveFailed(String)
    /// The one-time copy of the v1 file failed, so the v1 file was not overwritten.
    case v1BackupFailed(String)
}

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
    static let maximumBackups = 5
    let unsaved = UnsavedChanges()
    private(set) var plan: Plan
    /// Increments when the whole plan is replaced (import, reset), so open editors reload their drafts.
    private(set) var loadToken = 0
    private(set) var recoveryMode = false
    var storageIssue: StorageIssue?
    var errorMessage: String?
    var showImport = false
    var showExport = false
    var exportKind: ExportKind = .json
    var exportText = ""
    /// The app's own `Application Support/Purrtion` directory. Backups are pruned only inside it.
    let directory: URL
    let storageURL: URL
    /// The file on disk is schema v1 and has not yet been copied to `plan-v1-backup.json`.
    private var needsV1Backup = false

    init() {
        // A bad bundled seed is a developer/build error; it is covered by unit tests.
        do { plan = try PlanCodec.sample() }
        catch { preconditionFailure("Invalid bundled sample: \(error.localizedDescription)") }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = support.appendingPathComponent("Purrtion", isDirectory: true)
        storageURL = directory.appendingPathComponent("plan.json")
        if FileManager.default.fileExists(atPath: storageURL.path) {
            needsV1Backup = Self.schemaVersion(at: storageURL) == 1
            do { plan = try Self.readPlan(at: storageURL) }
            catch { recoveryMode = true; storageIssue = .recovery }
        }
    }

    /// Today's local date; every calculation uses it as `asOf`.
    var asOf: String { Dates.todayLocal() }

    func calculate(_ candidate: Plan) -> PlanResult? { try? CalorieCalculator.calculate(candidate, asOf: asOf) }
    var result: PlanResult? { calculate(plan) }

    static func readPlan(at url: URL) throws -> Plan {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= PlanCodec.maximumImportBytes else { throw PlanError("Maximum import size is 1 MiB") }
        return try PlanCodec.decode(Data(contentsOf: url))
    }
    /// The `schemaVersion` of a JSON file, read independently of full decoding (also works for damaged plans).
    private static func schemaVersion(at url: URL) -> Int? {
        struct Header: Decodable { let schemaVersion: Int }
        guard let data = try? Data(contentsOf: url), data.count <= PlanCodec.maximumImportBytes else { return nil }
        return (try? JSONDecoder().decode(Header.self, from: data))?.schemaVersion
    }

    func save(_ candidate: Plan) throws {
        try PlanValidator.validate(candidate)
        plan = candidate
        guard !recoveryMode else { return } // Never overwrite damaged data implicitly.
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if needsV1Backup {
                do { try backUpV1File() }
                catch { storageIssue = .v1BackupFailed(error.localizedDescription); return }
                needsV1Backup = false
            }
            try PlanCodec.encode(plan).write(to: storageURL, options: .atomic)
            storageIssue = nil
        } catch {
            storageIssue = .saveFailed(error.localizedDescription)
        }
    }
    func replace(_ candidate: Plan) throws {
        try PlanValidator.validate(candidate)
        if FileManager.default.fileExists(atPath: storageURL.path) {
            // Keep the previous bytes, including unreadable data, before an explicit replacement.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = directory.appendingPathComponent("plan-backup-\(stamp)-\(UUID().uuidString.prefix(8)).json")
            try FileManager.default.copyItem(at: storageURL, to: backup)
            pruneBackups()
        }
        recoveryMode = false
        if storageIssue == .recovery { storageIssue = nil }
        try save(candidate)
        loadToken += 1
    }
    func reset() throws { try replace(PlanCodec.sample()) }

    /// Copies the v1 file to `plan-v1-backup.json` before the first v2 write (ENGINE.md §9). Never overwrites an existing backup.
    private func backUpV1File() throws {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        var target = directory.appendingPathComponent("plan-v1-backup.json")
        if FileManager.default.fileExists(atPath: target.path) {
            target = directory.appendingPathComponent("plan-v1-backup-\(Int(Date().timeIntervalSince1970)).json")
        }
        try FileManager.default.copyItem(at: storageURL, to: target)
    }

    /// A backup file name exactly of the form `plan-backup-*.json` (letters, digits, `-`, `_` in the middle).
    nonisolated static func isBackupName(_ name: String) -> Bool {
        name.range(of: "^plan-backup-[A-Za-z0-9_-]+\\.json$", options: .regularExpression) != nil
    }
    /// Allowlist guard for pruning: a regular file (not a directory or symlink) with a backup name,
    /// directly inside the app's own storage directory.
    nonisolated static func isPrunable(_ url: URL, isRegularFile: Bool, isSymbolicLink: Bool, directory: URL) -> Bool {
        isRegularFile && !isSymbolicLink && isBackupName(url.lastPathComponent)
            && url.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path
            && directory.lastPathComponent == "Purrtion"
    }
    /// Keeps the `maximumBackups` newest backups. Deletes individual files only; never directories, never recursively.
    private func pruneBackups() {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys,
                                                                      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { return }
        var backups: [(url: URL, date: Date)] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  Self.isPrunable(url, isRegularFile: values.isRegularFile ?? false, isSymbolicLink: values.isSymbolicLink ?? true,
                                  directory: directory) else { continue }
            backups.append((url, values.contentModificationDate ?? .distantPast))
        }
        backups.sort { $0.date != $1.date ? $0.date > $1.date : $0.url.lastPathComponent > $1.url.lastPathComponent }
        for old in backups.dropFirst(Self.maximumBackups) {
            try? FileManager.default.removeItem(at: old.url)
        }
    }

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
