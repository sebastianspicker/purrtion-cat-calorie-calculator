import Foundation

/// Which build is running. `script/build_and_run.sh` writes the version and the git commit into Info.plist;
/// `swift run` has no Info.plist, so both are nil and the app reports a development build.
enum BuildInfo {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    static let build = Bundle.main.object(forInfoDictionaryKey: "PurrtionBuild") as? String
    /// Where testers report problems; the website links to the same page.
    static let reportURL = URL(string: "https://github.com/sebastianspicker/purrtion-cat-calorie-calculator/issues")!
}
