import Foundation

/// Problems with the local file; the app localises them.
public enum StorageIssue: Equatable, Sendable {
    /// The saved file could not be read and has not been overwritten.
    case recovery
    /// Changes are in memory but could not be written.
    case saveFailed(String)
    /// The one-time copy of the v1 file failed, so the v1 file was not overwritten.
    case v1BackupFailed(String)
}

/// The plan file on disk, without UI state, so its data-protecting rules can be tested against a temporary directory:
/// damaged data is never overwritten implicitly, a v1 file is copied once before the first v2 write,
/// and an explicit replacement keeps a backup of the previous bytes.
public final class PlanFileStore {
    public static let maximumBackups = 5
    public private(set) var plan: Plan
    public private(set) var recoveryMode = false
    public private(set) var storageIssue: StorageIssue?
    /// The app's own storage directory (named `Purrtion`). Backups are pruned only inside it.
    public let directory: URL
    public let storageURL: URL
    /// The file on disk is schema v1 and has not yet been copied to `plan-v1-backup.json`.
    private var needsV1Backup = false

    /// Reads `plan.json` in `directory`. No file gives `sample`; an unreadable file enters recovery mode and keeps `sample` in memory.
    public init(directory: URL, sample: Plan) {
        self.directory = directory
        storageURL = directory.appendingPathComponent("plan.json")
        plan = sample
        if FileManager.default.fileExists(atPath: storageURL.path) {
            needsV1Backup = Self.schemaVersion(at: storageURL) == 1
            do { plan = try Self.readPlan(at: storageURL) }
            catch { recoveryMode = true; storageIssue = .recovery }
        }
    }

    public static func readPlan(at url: URL) throws -> Plan {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= PlanCodec.maximumImportBytes else { throw PlanError("Maximum import size is 10 MiB") }
        return try PlanCodec.decode(Data(contentsOf: url))
    }
    /// The `schemaVersion` of a JSON file, read independently of full decoding (also works for damaged plans).
    private static func schemaVersion(at url: URL) -> Int? {
        struct Header: Decodable { let schemaVersion: Int }
        guard let data = try? Data(contentsOf: url), data.count <= PlanCodec.maximumImportBytes else { return nil }
        return (try? JSONDecoder().decode(Header.self, from: data))?.schemaVersion
    }

    /// Validates and keeps `candidate`, then writes it unless in recovery mode. A failed write does not throw:
    /// it sets `storageIssue`, and the plan stays in memory.
    public func save(_ candidate: Plan) throws {
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
    /// An explicit replacement (import, reset): backs up the current file, including unreadable data, then leaves recovery mode and saves.
    public func replace(_ candidate: Plan) throws {
        try PlanValidator.validate(candidate)
        if FileManager.default.fileExists(atPath: storageURL.path) {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = directory.appendingPathComponent("plan-backup-\(stamp)-\(UUID().uuidString.prefix(8)).json")
            try FileManager.default.copyItem(at: storageURL, to: backup)
            pruneBackups()
        }
        recoveryMode = false
        if storageIssue == .recovery { storageIssue = nil }
        try save(candidate)
    }

    /// Copies the v1 file to `plan-v1-backup.json` before the first v2 write (ENGINE.md §9). Never overwrites an existing backup.
    private func backUpV1File() throws {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        var target = directory.appendingPathComponent("plan-v1-backup.json")
        if FileManager.default.fileExists(atPath: target.path) {
            target = directory.appendingPathComponent("plan-v1-backup-\(Int(Date().timeIntervalSince1970)).json")
        }
        try FileManager.default.copyItem(at: storageURL, to: target)
    }

    /// Keeps the `maximumBackups` newest backups. Deletes individual files only; never directories, never recursively.
    private func pruneBackups() {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys,
                                                                      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { return }
        var backups: [(url: URL, date: Date)] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  BackupFiles.isPrunable(url, isRegularFile: values.isRegularFile ?? false, isSymbolicLink: values.isSymbolicLink ?? true,
                                         directory: directory) else { continue }
            backups.append((url, values.contentModificationDate ?? .distantPast))
        }
        backups.sort { $0.date != $1.date ? $0.date > $1.date : $0.url.lastPathComponent > $1.url.lastPathComponent }
        for old in backups.dropFirst(Self.maximumBackups) {
            try? FileManager.default.removeItem(at: old.url)
        }
    }
}
