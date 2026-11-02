import Foundation
import XCTest
@testable import PurrtionCore

/// Pure checks on URL values only; nothing here touches the disk or deletes anything.
final class BackupFilesTests: XCTestCase {
    private let dir = URL(fileURLWithPath: "/x/Purrtion")
    private func prunable(_ url: String, directory: URL? = nil, regular: Bool = true, symlink: Bool = false) -> Bool {
        BackupFiles.isPrunable(URL(fileURLWithPath: url), isRegularFile: regular, isSymbolicLink: symlink, directory: directory ?? dir)
    }
    func testAcceptsBackupInStorageDirectory() {
        XCTAssertTrue(prunable("/x/Purrtion/plan-backup-1730000000-ABCD1234.json"))
    }
    func testRefusesEverythingElse() {
        XCTAssertFalse(prunable("/x/Purrtion/plan.json"))
        XCTAssertFalse(prunable("/x/Purrtion/plan-backup-1.json.bak"))
        XCTAssertFalse(prunable("/x/Purrtion/plan-backup-a b.json"))
        XCTAssertFalse(prunable("/x/Purrtion/sub/plan-backup-1.json"))
        XCTAssertFalse(prunable("/x/Other/plan-backup-1.json", directory: URL(fileURLWithPath: "/x/Other")))
        XCTAssertFalse(prunable("/x/Purrtion/plan-backup-1.json", symlink: true))
        XCTAssertFalse(prunable("/x/Purrtion/plan-backup-1.json", regular: false))
    }
}
