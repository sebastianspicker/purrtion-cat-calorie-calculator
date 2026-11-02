import Foundation

/// Name and location rules for the app's plan backups; pure functions so the deleting code can be checked without touching the disk.
public enum BackupFiles {
    /// A backup file name exactly of the form `plan-backup-*.json` (letters, digits, `-`, `_` in the middle).
    public static func isBackupName(_ name: String) -> Bool {
        name.range(of: "^plan-backup-[A-Za-z0-9_-]+\\.json$", options: .regularExpression) != nil
    }
    /// Allowlist guard for pruning: a regular file (not a directory or symlink) with a backup name,
    /// directly inside the app's own storage directory.
    public static func isPrunable(_ url: URL, isRegularFile: Bool, isSymbolicLink: Bool, directory: URL) -> Bool {
        isRegularFile && !isSymbolicLink && isBackupName(url.lastPathComponent)
            && url.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path
            && directory.lastPathComponent == "Purrtion"
    }
}
