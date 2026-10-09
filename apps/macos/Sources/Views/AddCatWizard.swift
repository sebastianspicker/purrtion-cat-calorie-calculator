import SwiftUI
import PurrtionCore

/// Guided "Add a cat": one question per step with Professor Purr. Nothing is saved until Create.
/// The target is set only by an explicit choice on the summary step (docs/ENGINE.md).
@MainActor
struct AddCatWizard: View {
    enum Step: Hashable, CaseIterable { case name, icon, age, weight, neutered, lifestyle, bcs, details, health, goal, foods, summary }
    enum TargetChoice: Hashable { case estimate, manual }

    let store: PlanStore
    let onCreated: (String) -> Void
    @State private var draft: Cat
    @State private var step: Step = .name
    @State private var ageMode: AgeMode = .unknown
    @State private var weight: Double?
    @State private var invalidFields = Set<String>()
    @State private var choice: TargetChoice = .estimate
    @State private var manualTarget: Double?
    @State private var manualSource: TargetSource = .owner
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l

    /// Placeholder target for the preview only; the estimate does not depend on it.
    private static let placeholderTarget: Double = 200

    init(store: PlanStore, onCreated: @escaping (String) -> Void) {
        self.store = store; self.onCreated = onCreated
        let balance = store.plan.foods.first { $0.type == .dry }?.id ?? store.plan.foods.first?.id ?? ""
        _draft = State(initialValue: Cat(id: newId("cat"), name: "", weightKg: 0, goal: .maintain, targetKcal: Self.placeholderTarget,
                                         targetSource: .provisional, extraKcal: 0, balanceFoodId: balance, meals: []))
    }

    private var asOf: String { store.asOf }
    private var weightValid: Bool { weight.map { $0 >= 0.1 && $0 <= 40 } ?? false }
    private func cat(target: Double, source: TargetSource) -> Cat {
        var cat = draft
        cat.weightKg = weight ?? 0; cat.targetKcal = target; cat.targetSource = source
        return cat
    }
    private func result(for cat: Cat) -> CatResult? {
        guard weightValid, invalidFields.isEmpty else { return nil }
        return store.calculate(store.plan.with(cat))?.cats.first { $0.id == cat.id }
    }
    /// The estimate, computed with a placeholder target.
    private var estimateResult: CatResult? { result(for: cat(target: Self.placeholderTarget, source: .provisional)) }
    private var stage: Stage? { (try? Estimator.stageOf(cat(target: Self.placeholderTarget, source: .provisional), asOf: asOf)) ?? nil }
    private var ageYears: Double? {
        ((try? Estimator.ageInDays(draft.profile, asOf: asOf)) ?? nil).map { floor($0 / EnergyModel.Units.daysPerYear) }
    }
    private var reproductionRelevant: Bool { draft.profile.sex == .female && draft.profile.neutered != .yes }
    private var steps: [Step] {
        Step.allCases.filter { $0 != .details || stage == .kitten || reproductionRelevant }
    }
    private var index: Int { steps.firstIndex(of: step) ?? 0 }
    private var availableGoals: [Goal] {
        let bcs = draft.profile.bcs ?? 0
        return Goal.allCases.filter { $0 == .maintain || ($0 == .loss && Double(bcs) >= EnergyModel.Bcs.overweightMin)
            || ($0 == .gain && Double(bcs) == EnergyModel.Bcs.gainOnly) }
    }
    private var isRefer: Bool { step == .summary && estimateResult?.estimate.status == .refer }
    private var canUseEstimate: Bool {
        guard let e = estimateResult?.estimate else { return false }
        return e.status == .ok && e.startKcal != nil
    }
    private var finalCat: Cat? {
        if choice == .estimate, canUseEstimate, let start = estimateResult?.estimate.startKcal {
            return cat(target: targetKcal(from: start), source: .provisional)
        }
        guard let target = manualTarget, target >= 1, target <= 3000 else { return nil }
        return cat(target: target, source: manualSource)
    }
    private var canAdvance: Bool {
        guard invalidFields.isEmpty else { return false }
        switch step {
        case .name: return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        case .weight: return weightValid
        case .foods: return store.plan.food(draft.balanceFoodId) != nil
        default: return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !isRefer { ProfessorPurr(text: guideText, expression: guideExpression) }
                    content
                }
                .padding(22)
            }
            Divider()
            footer
        }
        .frame(width: 780, height: 660)
        .background(Theme.paper)
        .onChange(of: draft.profile.bcs) { _, _ in
            if !availableGoals.contains(draft.goal) { draft.goal = .maintain }
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Text(l.t("wizard.title")).roundedHeading(.title2)
            Spacer()
            Text(l.t("wizard.stepOf", ["n": String(index + 1), "total": String(steps.count)])).monospacedDigit().foregroundStyle(Theme.muted)
        }
        .padding(18)
    }

    private var footer: some View {
        HStack {
            Button(l.t("common.cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Theme.alert).lineLimit(2) }
            Spacer()
            Button(l.t("wizard.back")) { if index > 0 { step = steps[index - 1] } }.disabled(index == 0)
            if step == .summary {
                Button(l.t("wizard.create")) { create() }
                    .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                    .keyboardShortcut(.defaultAction)
                    .disabled(finalCat == nil || !invalidFields.isEmpty)
            } else {
                Button(l.t("wizard.next")) { if index + 1 < steps.count { step = steps[index + 1] } }
                    .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdvance)
            }
        }
        .padding(16)
    }

    private var guideExpression: MascotExpression {
        switch step {
        case .summary: .happy
        case .bcs, .health, .goal: .thinking
        default: .curious
        }
    }
    private var guideText: String {
        switch step {
        case .name: l.t("wizard.say.name")
        case .icon: l.t("wizard.say.icon")
        case .age: l.t("wizard.say.age")
        case .weight: l.t("wizard.say.weight")
        case .neutered: l.t("wizard.say.neutered")
        case .lifestyle: l.t("wizard.say.lifestyle")
        case .bcs: l.t("wizard.say.bcs")
        case .details: l.t("wizard.say.details")
        case .health: l.t("wizard.say.health")
        case .goal: l.t("wizard.say.goal")
        case .foods: l.t("wizard.say.foods")
        case .summary: l.t("wizard.say.summary", ["name": draft.name])
        }
    }

    // MARK: Steps

    @ViewBuilder private var content: some View {
        switch step {
        case .name: nameStep
        case .icon: iconStep
        case .age: ageStep
        case .weight: weightStep
        case .neutered: neuteredStep
        case .lifestyle: lifestyleStep
        case .bcs: bcsStep
        case .details: detailsStep
        case .health: healthStep
        case .goal: goalStep
        case .foods: foodsStep
        case .summary: summaryStep
        }
    }

    private var nameStep: some View {
        Form { TextField(l.t("field.name"), text: $draft.name) }.formStyle(.grouped).scrollDisabled(true)
    }

    private var iconStep: some View {
        Form {
            Section { CatIconPicker(selection: $draft.icon) } footer: { Text(l.t("wizard.iconHelp")) }
        }
        .formStyle(.grouped).scrollDisabled(true)
    }

    private var ageStep: some View {
        Form {
            Picker(l.t("field.ageKnownAs"), selection: $ageMode) {
                Text(l.t("age.birthDate")).tag(AgeMode.birthDate)
                Text(l.t("age.approximate")).tag(AgeMode.approximate)
                Text(l.t("age.notSure")).tag(AgeMode.unknown)
            }
            .pickerStyle(.radioGroup)
            .onChange(of: ageMode) { _, mode in
                if mode == .birthDate { draft.profile.approxAgeYears = nil; if draft.profile.birthDate == nil { draft.profile.birthDate = ISODate.adding(days: -365, to: asOf) } }
                if mode == .approximate { draft.profile.birthDate = nil }
                if mode == .unknown { draft.profile.birthDate = nil; draft.profile.approxAgeYears = nil }
            }
            if ageMode == .birthDate {
                DatePicker(l.t("field.birthDate"), selection: Binding(
                    get: { draft.profile.birthDate.flatMap(ISODate.date) ?? ISODate.today() },
                    set: { draft.profile.birthDate = ISODate.string($0) }), in: ...Date(), displayedComponents: .date)
            } else if ageMode == .approximate {
                OptionalNumberEntry(label: l.t("field.approxAge"), key: "approx-age", value: $draft.profile.approxAgeYears, invalidFields: $invalidFields)
            }
        }
        .formStyle(.grouped).scrollDisabled(true)
    }

    private var weightStep: some View {
        Form {
            OptionalNumberEntry(label: l.t("field.weightKg"), key: "weight", value: $weight, invalidFields: $invalidFields, maxDecimals: 3)
            if let weight, !weightValid { Text(l.t("wizard.weightRange", ["kg": l.kg(weight)])).font(.caption).foregroundStyle(Theme.alert) }
            Label(l.t("wizard.weightTip"), systemImage: "lightbulb").font(.callout).foregroundStyle(Theme.muted)
        }
        .formStyle(.grouped).scrollDisabled(true)
    }

    private var neuteredStep: some View {
        Form {
            Picker(l.t("field.sex"), selection: $draft.profile.sex) { ForEach(Sex.allCases, id: \.self) { Text(l.sex($0)).tag($0) } }
                .pickerStyle(.radioGroup)
            Picker(l.t("field.neutered"), selection: $draft.profile.neutered) {
                ForEach(Neutered.allCases, id: \.self) { Text(l.neutered($0)).tag($0) }
            }
            .pickerStyle(.radioGroup)
        }
        .formStyle(.grouped).scrollDisabled(true)
    }

    private var lifestyleStep: some View {
        Form {
            Picker(l.t("field.lifestyle"), selection: $draft.profile.lifestyle) {
                Text(l.t("lifestyle.default")).tag(Lifestyle?.none)
                ForEach(Lifestyle.allCases, id: \.self) { Text(l.lifestyle($0)).tag(Lifestyle?.some($0)) }
            }
            .pickerStyle(.radioGroup)
            Text(draft.profile.lifestyle.map { l.lifestyleDescription($0) } ?? l.t("lifestyle.default.description"))
                .font(.callout).foregroundStyle(Theme.muted)
        }
        .formStyle(.grouped).scrollDisabled(true)
    }

    private var bcsStep: some View {
        Form {
            Picker(l.t("field.bcs"), selection: $draft.profile.bcs) {
                Text(l.t("bcs.notSure")).tag(Int?.none)
                ForEach(1...9, id: \.self) { score in Text("\(score): \(l.bcsDescription(score))").tag(Int?.some(score)) }
            }
            .pickerStyle(.radioGroup)
            if let years = ageYears, years >= EnergyModel.Age.mcsRequiredMinYears {
                Picker(l.t("field.mcs"), selection: $draft.profile.mcs) {
                    Text(l.t("mcs.none")).tag(MuscleCondition?.none)
                    ForEach(MuscleCondition.allCases, id: \.self) { Text(l.mcs($0)).tag(MuscleCondition?.some($0)) }
                }
                Text(l.t("mcs.help")).font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .formStyle(.grouped)
    }

    private var detailsStep: some View {
        Form {
            if stage == .kitten {
                OptionalNumberEntry(label: l.t("field.expectedAdult"), key: "adult", value: $draft.profile.expectedAdultWeightKg,
                                    invalidFields: $invalidFields, maxDecimals: 3)
                Text(l.t("wizard.expectedAdultHelp")).font(.caption).foregroundStyle(Theme.muted)
            }
            if reproductionRelevant {
                Picker(l.t("field.reproduction"), selection: $draft.profile.reproduction.status) {
                    ForEach(ReproductionStatus.allCases, id: \.self) { Text(l.reproduction($0)).tag($0) }
                }
                if draft.profile.reproduction.status == .gestation {
                    OptionalNumberEntry(label: l.t("field.preBreeding"), key: "pre-breeding",
                                        value: $draft.profile.reproduction.preBreedingWeightKg, invalidFields: $invalidFields, maxDecimals: 3)
                }
                if draft.profile.reproduction.status == .lactation {
                    OptionalIntPicker(label: l.t("field.litterSize"), range: 1...12, value: $draft.profile.reproduction.litterSize)
                    OptionalIntPicker(label: l.t("field.lactationWeek"), range: 1...12, value: $draft.profile.reproduction.lactationWeek)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var healthStep: some View {
        Form {
            Section(l.t("health.acute")) {
                ForEach(MedicalFlag.allCases.filter(\.isAcute), id: \.self) { flag in Toggle(l.medical(flag), isOn: medical(flag)) }
            }
            Section(l.t("health.chronic")) {
                ForEach(MedicalFlag.allCases.filter { !$0.isAcute }, id: \.self) { flag in Toggle(l.medical(flag), isOn: medical(flag)) }
            }
            Section { Toggle(l.t("field.endOfLife"), isOn: $draft.profile.endOfLife) }
        }
        .formStyle(.grouped)
    }

    private var goalStep: some View {
        Form {
            Picker(l.t("field.goal"), selection: $draft.goal) {
                ForEach(availableGoals, id: \.self) { Text(l.goal($0)).tag($0) }
            }
            .pickerStyle(.radioGroup)
            if availableGoals.count == 1 { Text(l.t("wizard.goalOnlyMaintain")).font(.callout).foregroundStyle(Theme.muted) }
        }
        .formStyle(.grouped).scrollDisabled(true)
    }

    private var foodsStep: some View {
        Form {
            Section(l.t("editor.section.balance")) {
                Picker(l.t("field.balanceFood"), selection: $draft.balanceFoodId) {
                    ForEach(store.plan.foods) { food in Text(food.name).tag(food.id) }
                }
                Text(l.t("editor.balanceHelp")).font(.caption).foregroundStyle(Theme.muted)
            }
            Section(l.t("editor.section.meals")) {
                ForEach(draft.meals) { row in
                    let meal = elementBinding($draft.meals, id: row.id, fallback: row)
                    HStack(alignment: .top) {
                        Picker(l.t("field.food"), selection: meal.foodId) {
                            ForEach(store.plan.foods) { food in Text(food.name).tag(food.id) }
                        }
                        NumberEntry(label: l.t("field.gramsEaten"), key: row.id, value: meal.grams, invalidFields: $invalidFields)
                            .frame(width: 140)
                        Button(l.t("common.remove"), role: .destructive) { draft.meals.removeAll { $0.id == row.id } }
                            .buttonStyle(.borderless)
                    }
                }
                Button(l.t("editor.addMeal"), systemImage: "plus") {
                    guard let food = store.plan.foods.first else { return }
                    draft.meals.append(Meal(id: newId("meal"), label: l.t("wizard.mealLabel", ["n": String(draft.meals.count + 1)]),
                                            foodId: food.id, grams: 0))
                }
                .disabled(draft.meals.count >= 24)
                Text(l.t("editor.mealsHelp")).font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var summaryStep: some View {
        HStack(spacing: 10) {
            CatAvatar(id: draft.id, icon: draft.icon, size: 48)
            Text(draft.name).roundedHeading(.title3).lineLimit(1)
        }
        if let result = estimateResult {
            let e = result.estimate
            if e.status == .refer {
                ReferralPanel(reasons: e.reasons)
                Text(l.t("wizard.referManual")).font(.callout)
                manualTargetFields
            } else {
                let shown = choice == .manual ? (finalCat.flatMap { self.result(for: $0) } ?? result) : result
                EstimateSection(cat: finalCat ?? cat(target: Self.placeholderTarget, source: .provisional), result: shown, asOf: asOf,
                                showsComparison: choice == .manual && finalCat != nil)
                    .stickerCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text(l.t("wizard.targetTitle")).roundedHeading(.headline)
                    Picker(l.t("wizard.targetTitle"), selection: $choice) {
                        if canUseEstimate, let start = e.startKcal {
                            Text(l.t("wizard.useEstimate", ["kcal": l.int(start)])).tag(TargetChoice.estimate)
                        }
                        Text(l.t("wizard.ownTarget")).tag(TargetChoice.manual)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    if choice == .manual || !canUseEstimate { manualTargetFields }
                }
                .stickerCard()
                .onAppear { if !canUseEstimate { choice = .manual } }
            }
        } else {
            Text(l.t("editor.invalidPreview")).foregroundStyle(Theme.muted)
        }
    }

    private var manualTargetFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            OptionalNumberEntry(label: l.t("field.target"), key: "manual-target", value: $manualTarget, invalidFields: $invalidFields)
                .frame(maxWidth: 260)
            Picker(l.t("field.targetSource"), selection: $manualSource) {
                Text(l.targetSource(.owner)).tag(TargetSource.owner)
                Text(l.targetSource(.veterinarian)).tag(TargetSource.veterinarian)
            }
            .frame(maxWidth: 360)
        }
        .onAppear { if isRefer { choice = .manual } }
    }

    // MARK: Actions

    private func medical(_ flag: MedicalFlag) -> Binding<Bool> {
        Binding(get: { draft.profile.medical.contains(flag) }, set: { on in
            var flags = Set(draft.profile.medical)
            if on { flags.insert(flag) } else { flags.remove(flag) }
            draft.profile.medical = MedicalFlag.allCases.filter { flags.contains($0) }
        })
    }

    private func create() {
        // On a referral only a manually entered target is allowed.
        if isRefer { choice = .manual }
        guard let cat = finalCat else { return }
        do {
            try store.save(store.plan.with(cat))
            onCreated(cat.id)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

/// Quick add: name, weight, an explicit target and the balance food.
@MainActor
struct QuickAddCatView: View {
    let store: PlanStore
    let onCreated: (String) -> Void
    @State private var name = ""
    @State private var weight: Double?
    @State private var target: Double?
    @State private var source: TargetSource = .owner
    @State private var balanceFoodId: String
    @State private var invalidFields = Set<String>()
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l

    init(store: PlanStore, onCreated: @escaping (String) -> Void) {
        self.store = store; self.onCreated = onCreated
        _balanceFoodId = State(initialValue: store.plan.foods.first { $0.type == .dry }?.id ?? store.plan.foods.first?.id ?? "")
    }

    var body: some View {
        Form {
            Section(l.t("quick.title")) {
                Text(l.t("quick.help")).font(.caption).foregroundStyle(Theme.muted)
                TextField(l.t("field.name"), text: $name)
                OptionalNumberEntry(label: l.t("field.weightKg"), key: "weight", value: $weight, invalidFields: $invalidFields, maxDecimals: 3)
                OptionalNumberEntry(label: l.t("field.target"), key: "target", value: $target, invalidFields: $invalidFields)
                Picker(l.t("field.targetSource"), selection: $source) {
                    ForEach(TargetSource.allCases, id: \.self) { Text(l.targetSource($0)).tag($0) }
                }
                Picker(l.t("field.balanceFood"), selection: $balanceFoodId) {
                    ForEach(store.plan.foods) { food in Text(food.name).tag(food.id) }
                }
            }
            Section {
                if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Theme.alert) }
                HStack {
                    Button(l.t("wizard.create")) { create() }
                        .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                        .disabled(!invalidFields.isEmpty || weight == nil || target == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(l.t("common.cancel")) { dismiss() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 460)
    }

    private func create() {
        guard let weight, let target else { return }
        let cat = Cat(id: newId("cat"), name: name, weightKg: weight, goal: .maintain, targetKcal: target, targetSource: source,
                      extraKcal: 0, balanceFoodId: balanceFoodId, meals: [])
        do { try store.save(store.plan.with(cat)); onCreated(cat.id); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
