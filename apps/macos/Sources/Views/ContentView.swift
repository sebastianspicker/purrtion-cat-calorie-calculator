import SwiftUI
import UniformTypeIdentifiers
import PurrtionCore

@MainActor
struct ContentView: View {
    @Bindable var store: PlanStore
    @SceneStorage("purrtion.selection") private var selected = "household"
    @State private var pendingImport: Plan?
    @State private var showWizard = false
    @State private var showQuickAdd = false
    @State private var showActivities = false
    @State private var pendingSelection: String?
    @Environment(\.l10n) private var l

    private var selection: Binding<String?> {
        Binding(get: { selected }, set: { requestSelection($0 ?? "household") })
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                if let issue = store.storageIssue {
                    Label(storageText(issue), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(Theme.alert).padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                detail
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItemGroup {
                    Button(l.t("toolbar.import"), systemImage: "square.and.arrow.down") { store.showImport = true }
                    Menu {
                        Button(l.t("menu.exportJSON")) { store.prepareExport(.json) }
                        Button(l.t("menu.exportCSV")) { store.prepareExport(.csv) }
                    } label: { Label(l.t("toolbar.export"), systemImage: "square.and.arrow.up") }
                    Button(l.t("toolbar.activities"), systemImage: "puzzlepiece") { showActivities = true }
                }
            }
        }
        .fileImporter(isPresented: $store.showImport, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                pendingImport = try PlanStore.readPlan(at: url)
            } catch { store.errorMessage = error.localizedDescription }
        }
        .confirmationDialog(l.t("import.title"), isPresented: Binding(
            get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
            Button(l.t("import.replace"), role: .destructive) {
                guard let candidate = pendingImport else { return }
                do { try store.replace(candidate); selected = "household" }
                catch { store.errorMessage = error.localizedDescription }
                pendingImport = nil
            }
            Button(l.t("common.cancel"), role: .cancel) { pendingImport = nil }
        } message: { Text(l.t("import.message")) }
        .fileExporter(isPresented: $store.showExport, document: PlanTextDocument(text: store.exportText),
                      contentType: store.exportKind == .json ? .json : .commaSeparatedText,
                      defaultFilename: store.exportKind == .json ? "purrtion-plan.json" : "purrtion-portions.csv") { result in
            if case .failure(let error) = result { store.errorMessage = error.localizedDescription }
        }
        .alert(l.t("alert.title"), isPresented: Binding(
            get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button(l.t("common.ok")) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .confirmationDialog(l.t("unsaved.title"), isPresented: Binding(
            get: { pendingSelection != nil }, set: { if !$0 { pendingSelection = nil } }), titleVisibility: .visible) {
            Button(l.t("unsaved.save")) {
                if let next = pendingSelection, store.unsaved.save() { selected = next }
                pendingSelection = nil
            }
            Button(l.t("unsaved.discard"), role: .destructive) {
                if let next = pendingSelection { store.unsaved.discard(); selected = next }
                pendingSelection = nil
            }
            Button(l.t("common.cancel"), role: .cancel) { pendingSelection = nil }
        } message: { Text(l.t("unsaved.message")) }
        .sheet(isPresented: $showWizard) {
            AddCatWizard(store: store) { id in selected = "cat:\(id)" }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddCatView(store: store) { id in selected = "cat:\(id)" }
        }
        .sheet(isPresented: $showActivities) { ActivityEditorView(store: store) }
    }

    /// Leaving a cat with unsaved edits asks first: Save, Discard or Cancel (Cancel keeps the current selection).
    private func requestSelection(_ new: String) {
        guard new != selected else { return }
        if store.unsaved.hasChanges { pendingSelection = new } else { selected = new }
    }

    private var sidebar: some View {
        List(selection: selection) {
            HStack(spacing: 10) {
                BrandMark(size: 38)
                Text("Purrtion").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            }
            .padding(.vertical, 6)
            .selectionDisabled()
            Section(l.t("nav.section.plan")) {
                Label(l.t("nav.household"), systemImage: "chart.bar.doc.horizontal").tag("household")
                Label(l.t("nav.foods"), systemImage: "takeoutbag.and.cup.and.straw").tag("foods")
                Label(l.t("nav.method"), systemImage: "info.circle").tag("method")
            }
            Section(l.t("nav.section.cats")) {
                ForEach(store.plan.cats) { cat in
                    HStack(spacing: 8) {
                        CatAvatar(id: cat.id, icon: cat.icon, size: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.name)
                            Text(l.t("nav.catDetail", ["weight": l.kg(cat.weightKg), "goal": l.goal(cat.goal)]))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag("cat:\(cat.id)")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 320)
        .safeAreaInset(edge: .bottom) {
            Menu {
                Button(l.t("addCat.guided")) { showWizard = true }
                Button(l.t("addCat.quick")) { showQuickAdd = true }
            } label: {
                Label(l.t("addCat.title"), systemImage: "plus")
            } primaryAction: {
                showWizard = true
            }
            .menuStyle(.borderlessButton)
            .disabled(store.plan.cats.count >= 50)
            .padding().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var detail: some View {
        if selected == "foods" { FoodLibraryView(store: store) }
        else if selected == "method" { MethodView(store: store) }
        else if selected.hasPrefix("cat:"), let cat = store.plan.cats.first(where: { "cat:\($0.id)" == selected }) {
            CatEditorView(store: store, initial: cat) { selected = "household" }
                .id("\(cat.id)-\(store.loadToken)")
        } else {
            HouseholdView(store: store) { id in selected = "cat:\(id)" }
        }
    }

    private var title: String {
        if selected == "foods" { return l.t("nav.foods") }
        if selected == "method" { return l.t("nav.method") }
        return store.plan.cats.first(where: { "cat:\($0.id)" == selected })?.name ?? l.t("nav.householdTitle")
    }

    private func storageText(_ issue: StorageIssue) -> String {
        switch issue {
        case .recovery: return l.t("storage.recovery")
        case .saveFailed(let detail): return l.t("storage.saveFailed", ["detail": detail])
        case .v1BackupFailed(let detail): return l.t("storage.v1BackupFailed", ["detail": detail])
        }
    }
}
