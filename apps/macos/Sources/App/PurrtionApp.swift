import SwiftUI
import AppKit

@main
@MainActor
struct PurrtionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = PlanStore()
    @AppStorage(L10n.storageKey) private var language = AppLanguage.system.rawValue

    private var l: L10n { L10n.resolve(language) }

    var body: some Scene {
        WindowGroup("Purrtion") {
            ContentView(store: store)
                .onAppear { delegate.store = store }
                .frame(minWidth: 1000, minHeight: 680)
                .environment(\.l10n, l)
                .environment(\.locale, l.locale)
        }
        .defaultSize(width: 1260, height: 840)
        .commands {
            CommandGroup(after: .newItem) {
                Button(l.t("menu.import")) { store.showImport = true }
                    .keyboardShortcut("o", modifiers: .command)
                Button(l.t("menu.exportJSONLong")) { store.prepareExport(.json) }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button(l.t("menu.exportCSVLong")) { store.prepareExport(.csv) }
                Divider()
            }
            CommandGroup(replacing: .help) {
                Link(l.t("menu.reportProblem"), destination: BuildInfo.reportURL)
            }
        }
        Settings {
            SettingsView(store: store, language: $language)
                .environment(\.l10n, l)
                .environment(\.locale, l.locale)
        }
    }
}

@MainActor
struct SettingsView: View {
    let store: PlanStore
    @Binding var language: String
    @Environment(\.l10n) private var l
    var body: some View {
        Form {
            Picker(l.t("settings.language"), selection: $language) {
                Text(l.t("settings.language.system")).tag(AppLanguage.system.rawValue)
                Text("English").tag(AppLanguage.en.rawValue)
                Text("Deutsch").tag(AppLanguage.de.rawValue)
            }
            Section(l.t("settings.local")) {
                Text(l.t("settings.localText"))
                Text(l.t("settings.dataPath", ["path": store.storageURL.path]))
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Section(l.t("settings.about")) {
                if let version = BuildInfo.version, let build = BuildInfo.build {
                    Text(l.t("settings.version", ["version": version, "build": build])).textSelection(.enabled)
                } else {
                    Text(l.t("settings.devBuild"))
                }
                Link(l.t("settings.report"), destination: BuildInfo.reportURL)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .padding(8)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: PlanStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        // A plan that is in memory but failed to reach the disk counts as unsaved too.
        let failure: String? = switch store.storageIssue { case .saveFailed(let detail), .v1BackupFailed(let detail): detail; default: nil }
        let unwritten = failure != nil
        guard store.unsaved.hasChanges || unwritten else { return .terminateNow }
        let l = L10n.resolve(UserDefaults.standard.string(forKey: L10n.storageKey) ?? AppLanguage.system.rawValue)
        let alert = NSAlert()
        alert.messageText = l.t("unsaved.title")
        alert.informativeText = store.unsaved.hasChanges ? l.t("unsaved.message") : l.t("storage.saveFailed", ["detail": failure ?? ""])
        alert.addButton(withTitle: l.t("unsaved.save")); alert.addButton(withTitle: l.t("unsaved.discard")); alert.addButton(withTitle: l.t("common.cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            guard store.unsaved.save() else { return .terminateCancel }
            if unwritten && !store.recoveryMode { try? store.save(store.plan) } // retry the failed write once
            // Quit only when the plan really reached the disk; in recovery mode nothing is written, so the app stays open.
            return store.storageIssue == nil ? .terminateNow : .terminateCancel
        case .alertSecondButtonReturn: return .terminateNow
        default: return .terminateCancel
        }
    }
}
