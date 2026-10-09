import SwiftUI
import PurrtionCore

@MainActor
struct FoodEditorView: View {
    let store: PlanStore
    @State private var draft: Food
    @State private var invalidFields = Set<String>()
    @State private var error = ""
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l

    init(store: PlanStore, initial: Food) { self.store = store; _draft = State(initialValue: initial) }
    private var existing: Bool { store.plan.foods.contains { $0.id == draft.id } }
    private var inUse: Bool { store.plan.cats.contains { $0.balanceFoodId == draft.id || $0.meals.contains { $0.foodId == draft.id } } }
    private var candidate: Plan {
        var plan = store.plan
        if let index = plan.foods.firstIndex(where: { $0.id == draft.id }) { plan.foods[index] = draft } else { plan.foods.append(draft) }
        return plan
    }
    private var validationError: String? {
        guard invalidFields.isEmpty else { return nil }
        do { try PlanValidator.validate(candidate); return nil } catch { return error.localizedDescription }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Form {
                basics
                energy
                analysis
                actions
            }
            .formStyle(.grouped)
            .frame(width: 470)
            Divider()
            ScrollView { FoodAnalysisPanel(food: draft).padding(18) }
                .frame(width: 330)
                .background(Theme.paper)
        }
        .frame(height: 680)
        .confirmationDialog(l.t("food.deleteTitle"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(l.t("food.delete"), role: .destructive) {
                var plan = store.plan; plan.foods.removeAll { $0.id == draft.id }
                do { try store.save(plan); dismiss() } catch { self.error = error.localizedDescription }
            }
            Button(l.t("common.cancel"), role: .cancel) { }
        }
    }

    private var basics: some View {
        Section(existing ? l.t("food.edit") : l.t("food.new")) {
            TextField(l.t("food.name"), text: $draft.name)
            Picker(l.t("food.type"), selection: $draft.type) { ForEach(FoodType.allCases, id: \.self) { Text(l.foodType($0)).tag($0) } }
            Picker(l.t("food.completeness"), selection: $draft.completeness) {
                ForEach(Completeness.allCases, id: \.self) { Text(l.completeness($0)).tag($0) }
            }
            Picker(l.t("food.lifeStageClaim"), selection: $draft.lifeStageClaim) {
                ForEach(LifeStageClaim.allCases, id: \.self) { Text(l.lifeStageClaim($0)).tag($0) }
            }
            TextField(l.t("food.note"), text: $draft.note, axis: .vertical).lineLimit(2...5)
        }
    }

    private var energy: some View {
        Section(l.t("food.energy")) {
            Picker(l.t("food.energySource"), selection: Binding(get: { draft.energySource }, set: setSource)) {
                ForEach(EnergySource.allCases, id: \.self) { Text(l.energySource($0)).tag($0) }
            }
            Picker(l.t("food.unit"), selection: Binding(get: { draft.energyUnit }, set: setUnit)) {
                ForEach(EnergyUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if draft.energySource == .analysis {
                LabeledContent(l.t("food.computedEnergy")) {
                    Text(draft.displayEnergy.map { "\(l.num($0, digits: 1)) \(draft.energyUnit.rawValue)" } ?? "–").monospacedDigit()
                }
                Text(l.t("food.computedHelp")).font(.caption).foregroundStyle(Theme.muted)
            } else {
                NumberEntry(label: l.t("food.energyValue"), key: "energy", value: Binding(
                    get: { draft.energyPerUnit ?? 0 }, set: { draft.energyPerUnit = $0 }), invalidFields: $invalidFields, maxDecimals: 4)
                Text(l.t("food.unitHelp")).font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    @ViewBuilder private var analysis: some View {
        Section(l.t("food.analysis")) {
            Toggle(l.t("food.hasAnalysis"), isOn: Binding(get: { draft.analysis != nil }, set: { on in
                if on { draft.analysis = draft.analysis ?? Analysis(protein: 0, fat: 0, fibre: 0, ash: 0, moisture: draft.type == .dry ? nil : 0) }
                else if draft.energySource != .analysis { draft.analysis = nil }
            }))
            .disabled(draft.energySource == .analysis)
            if draft.analysis != nil {
                Text(l.t("food.analysisHelp")).font(.caption).foregroundStyle(Theme.muted)
                OptionalNumberEntry(label: l.t("food.moisture"), key: "moisture", value: Binding(
                    get: { draft.analysis?.moisture }, set: { draft.analysis?.moisture = $0 }), invalidFields: $invalidFields)
                if draft.type == .dry { Text(l.t("food.moistureDryHelp")).font(.caption).foregroundStyle(Theme.muted) }
                else if draft.analysis?.moisture == nil { Text(l.t("food.moistureWetRequired")).font(.caption).foregroundStyle(Theme.alert) }
                NumberEntry(label: l.t("food.protein"), key: "protein", value: constituent(\.protein), invalidFields: $invalidFields)
                NumberEntry(label: l.t("food.fat"), key: "fat", value: constituent(\.fat), invalidFields: $invalidFields)
                NumberEntry(label: l.t("food.fibre"), key: "fibre", value: constituent(\.fibre), invalidFields: $invalidFields)
                NumberEntry(label: l.t("food.ash"), key: "ash", value: constituent(\.ash), invalidFields: $invalidFields)
                Picker(l.t("food.kind"), selection: Binding(get: { draft.analysis?.kind ?? .prepared }, set: { draft.analysis?.kind = $0 })) {
                    ForEach(AnalysisKind.allCases, id: \.self) { Text(l.analysisKind($0)).tag($0) }
                }
            }
        }
    }

    private var actions: some View {
        Section {
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Theme.alert) }
            else if let message = validationError { Text(message).font(.caption).foregroundStyle(Theme.alert) }
            HStack {
                Button(existing ? l.t("food.save") : l.t("food.create")) {
                    do { try store.save(candidate); dismiss() } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                .disabled(!invalidFields.isEmpty || validationError != nil)
                Button(l.t("common.cancel")) { dismiss() }
                if existing {
                    Spacer()
                    Button(l.t("food.delete"), role: .destructive) { confirmDelete = true }.disabled(inUse)
                        .help(inUse ? l.t("food.inUse") : l.t("food.deleteHelp"))
                }
            }
        }
    }

    // MARK: Bindings

    private func constituent(_ keyPath: WritableKeyPath<Analysis, Double>) -> Binding<Double> {
        Binding(get: { draft.analysis?[keyPath: keyPath] ?? 0 }, set: { draft.analysis?[keyPath: keyPath] = $0 })
    }
    /// Changing the unit converts the stored number so the energy density is preserved.
    private func setUnit(_ unit: EnergyUnit) {
        if let value = draft.energyPerUnit, draft.energySource != .analysis {
            let kcalPerGram = FoodAnalysis.labelKcalPerGram(value, draft.energyUnit)
            draft.energyPerUnit = kcalPerGram * (unit.rawValue.hasSuffix("/kg") ? 1000 : 100)
                * (unit.rawValue.hasPrefix("kJ") ? EnergyModel.Units.kjPerKcal : 1)
        }
        draft.energyUnit = unit
    }
    /// Analysis energy needs an analysis and no declared value; switching back keeps the computed value as a starting point.
    private func setSource(_ source: EnergySource) {
        if source == .analysis {
            if draft.analysis == nil { draft.analysis = Analysis(protein: 0, fat: 0, fibre: 0, ash: 0, moisture: draft.type == .dry ? nil : 0) }
            draft.energySource = .analysis
            draft.energyPerUnit = nil
        } else {
            if draft.energySource == .analysis { draft.energyPerUnit = draft.displayEnergy.map { ($0 * 10).rounded() / 10 } }
            draft.energySource = source
        }
    }
}

/// Live derived values from `FoodAnalysis.analyse` (ENGINE.md §4).
struct FoodAnalysisPanel: View {
    let food: Food
    @Environment(\.l10n) private var l
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.t("food.derived")).roundedHeading(.title3)
            if let kcalPerGram = try? CalorieCalculator.kcalPerGram(food), kcalPerGram.isFinite, kcalPerGram > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.t("food.effectiveEnergy")).font(.caption).foregroundStyle(Theme.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(l.num(kcalPerGram * 100)).bigNumber(size: 30)
                        Text("kcal/100 g").foregroundStyle(Theme.muted)
                    }
                }
            }
            if let a = food.analysis, let r = analysed(food) {
                results(a, r)
            } else if food.analysis != nil {
                Text(l.t("food.analysisIncomplete")).foregroundStyle(Theme.muted)
            } else {
                Text(l.t("food.noAnalysis")).foregroundStyle(Theme.muted)
            }
        }
        .stickerCard()
    }

    /// The analysis result, or nil while the values cannot be evaluated (e.g. moisture 100 % or no energy yet).
    private func analysed(_ food: Food) -> FoodAnalysisResult? {
        guard let a = food.analysis, FoodAnalysis.moistureUsed(a) < 100, FoodAnalysis.meKcalPer100g(a) > 0 else { return nil }
        let r = FoodAnalysis.analyse(food)
        guard let r, [r.meKcalPer100g, r.atwaterKcalPer100g, r.proteinGPer1000kcal, r.carbGPer100kcal].allSatisfy(\.isFinite) else { return nil }
        return r
    }

    @ViewBuilder private func results(_ a: Analysis, _ r: FoodAnalysisResult) -> some View {
        EquationChips(equation: r.method.rawValue)
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            row(l.t("food.me4"), "\(l.num(r.meKcalPer100g)) kcal/100 g")
            row(l.t("food.atwater"), "\(l.num(r.atwaterKcalPer100g)) kcal/100 g")
            row(l.t("food.nfe"), l.percent(r.nfe))
            row(l.t("food.moistureUsed"), l.percent(r.moisture))
        }
        .font(.callout)
        Text(l.t("food.dryMatter")).font(.headline).fontDesign(.rounded)
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            row(l.t("food.protein"), l.percent(r.dryMatter.protein))
            row(l.t("food.fat"), l.percent(r.dryMatter.fat))
            row(l.t("food.fibre"), l.percent(r.dryMatter.fibre))
            row(l.t("food.ash"), l.percent(r.dryMatter.ash))
            row(l.t("food.nfe"), l.percent(r.dryMatter.nfe))
        }
        .font(.callout)
        Text(l.t("food.perEnergy")).font(.headline).fontDesign(.rounded)
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            row(l.t("food.proteinPer1000"), "\(l.num(r.proteinGPer1000kcal)) g")
            row(l.t("food.fatPer1000"), "\(l.num(r.fatGPer1000kcal)) g")
            row(l.t("food.carbPer100"), "\(l.num(r.carbGPer100kcal)) g")
            row(l.t("food.carbShare"), l.percent(r.energySharePercent.carbohydrate))
        }
        .font(.callout)
        Text(l.t("food.energyShares")).font(.headline).fontDesign(.rounded)
        EnergyShareBar(shares: r.energySharePercent)
        ForEach(r.warnings, id: \.self) { code in WarningLine(text: l.msg("food.\(code.rawValue)")) }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(Theme.muted); Text(value).monospacedDigit() }
    }
}

/// Protein / fat / carbohydrate share of metabolisable energy as a stacked bar with a legend.
struct EnergyShareBar: View {
    let shares: EnergyShares
    @Environment(\.l10n) private var l
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Theme.sakura).frame(width: geo.size.width * shares.protein / 100)
                    Rectangle().fill(Theme.yolk).frame(width: geo.size.width * shares.fat / 100)
                    Rectangle().fill(Theme.sky).frame(width: geo.size.width * shares.carbohydrate / 100)
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
            HStack(spacing: 12) {
                legend(Theme.sakura, l.t("food.protein"), shares.protein)
                legend(Theme.yolk, l.t("food.fat"), shares.fat)
                legend(Theme.sky, l.t("food.carbs"), shares.carbohydrate)
            }
            .font(.caption)
        }
        .accessibilityElement(children: .combine)
    }
    private func legend(_ color: Color, _ label: String, _ value: Double) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(l.percent(value, digits: 0))").monospacedDigit()
        }
    }
}
