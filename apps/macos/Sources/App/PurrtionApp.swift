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
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .padding(8)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
