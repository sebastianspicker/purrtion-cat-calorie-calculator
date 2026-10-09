import SwiftUI
import PurrtionCore

enum AgeMode: Hashable { case birthDate, approximate, unknown }

/// One cat: profile and plan form, weight log, and the live side panel. All edits change a draft; Save writes it.
/// Target changes from the estimator or the trend are explicit, confirmed actions (docs/ENGINE.md).
@MainActor
struct CatEditorView: View {
    enum Tab: Hashable { case plan, weights }
    let store: PlanStore
    let onRemoved: () -> Void
    @State private var draft: Cat
    @State private var tab: Tab = .plan
    @State private var ageMode: AgeMode
    @State private var invalidFields = Set<String>()
    @State private var error = ""
    @State private var confirmDelete = false
    @State private var pendingEstimate: EnergyEstimate?
    @State private var pendingSuggestion: Suggestion?
    @Environment(\.l10n) private var l

    init(store: PlanStore, initial: Cat, onRemoved: @escaping () -> Void) {
        self.store = store; self.onRemoved = onRemoved
        _draft = State(initialValue: initial)
        _ageMode = State(initialValue: initial.profile.birthDate != nil ? .birthDate
                         : initial.profile.approxAgeYears != nil ? .approximate : .unknown)
    }

    private var asOf: String { store.asOf }
    private var candidate: Plan { store.plan.with(draft) }
    private var preview: CatResult? {
        guard invalidFields.isEmpty else { return nil }
        return store.calculate(candidate)?.cats.first { $0.id == draft.id }
    }
    private var validationError: String? {
        do { try PlanValidator.validate(candidate); return nil } catch { return error.localizedDescription }
    }
    private var hasChanges: Bool { store.plan.cat(draft.id) != draft }
    /// The target counts as the veterinarian's when either the saved cat or the draft says so.
    private var targetIsVeterinarian: Bool { store.plan.cat(draft.id)?.targetSource == .veterinarian || draft.targetSource == .veterinarian }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Picker(l.t("editor.view"), selection: $tab) {
                    Text(l.t("editor.tab.plan")).tag(Tab.plan)
                    Text(l.t("editor.tab.weights")).tag(Tab.weights)
                }
                .pickerStyle(.segmented).labelsHidden().padding([.horizontal, .top], 16).padding(.bottom, 4)
                if tab == .plan {
                    CatProfileForm(draft: $draft, ageMode: $ageMode, invalidFields: $invalidFields, plan: store.plan, asOf: asOf)
                } else {
                    WeightLogView(cat: $draft, result: preview) { pendingSuggestion = $0 }
                }
                saveBar
            }
            .frame(maxWidth: .infinity)
            Divider()
            ScrollView { sidePanel.padding(18) }
                .frame(width: 360)
                .background(Theme.paper)
        }
        .onChange(of: draft, initial: true) { syncUnsaved() }
        .onChange(of: store.plan) { syncUnsaved() }
        .onChange(of: invalidFields) { syncUnsaved() }
        .onDisappear { store.unsaved.release(draft.id) }
        .confirmationDialog(l.t("confirm.useEstimate.title"), isPresented: Binding(
            get: { pendingEstimate != nil }, set: { if !$0 { pendingEstimate = nil } }), titleVisibility: .visible) {
            if let e = pendingEstimate, let start = e.startKcal {
                Button(targetIsVeterinarian ? l.t("confirm.vetDiscussed", ["kcal": l.int(start)])
                       : l.t("confirm.useEstimate.button", ["kcal": l.int(start)])) { applyEstimate(e) }
            }
            Button(l.t("common.cancel"), role: .cancel) { pendingEstimate = nil }
        } message: { Text(useEstimateMessage) }
        .confirmationDialog(l.t("confirm.suggestion.title"), isPresented: Binding(
            get: { pendingSuggestion != nil }, set: { if !$0 { pendingSuggestion = nil } }), titleVisibility: .visible) {
            if let s = pendingSuggestion {
                if let kcal = s.suggestedKcal {
                    Button(targetIsVeterinarian ? l.t("confirm.vetDiscussed", ["kcal": l.int(kcal)])
                           : l.t("confirm.suggestion.button", ["kcal": l.int(kcal)])) { applySuggestion(s) }
                } else if s.action == .switchToMaintenance {
                    Button(l.t("trend.switchGoal")) { applySuggestion(s) }
                }
            }
            Button(l.t("common.cancel"), role: .cancel) { pendingSuggestion = nil }
        } message: { Text(suggestionMessage) }
        .confirmationDialog(l.t("confirm.removeCat.title", ["name": draft.name]), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(l.t("editor.removeCat"), role: .destructive) {
                var plan = store.plan; plan.cats.removeAll { $0.id == draft.id }
                do { try store.save(plan); onRemoved() } catch { self.error = error.localizedDescription }
            }
            Button(l.t("common.cancel"), role: .cancel) { }
        }
    }

    /// Tells the sidebar whether leaving this cat needs a Save / Discard / Cancel question, and how to save.
    private func syncUnsaved() {
        store.unsaved.register(owner: draft.id, hasChanges: hasChanges) {
            guard invalidFields.isEmpty else { error = l.t("entry.invalidNumber"); return false }
            do { try store.save(candidate); error = ""; return true } catch { self.error = error.localizedDescription; return false }
        }
    }

    // MARK: Explicit target actions

    private var useEstimateMessage: String {
        guard let e = pendingEstimate else { return "" }
        var text = targetIsVeterinarian ? l.t("confirm.vetFirst") : l.t("confirm.useEstimate.message")
        if storesEstimatedIdealWeight(e), let ibw = e.idealWeight {
            text += "\n\n" + l.t("confirm.useEstimate.storesIdeal", ["kg": l.kg(ibw.kg)])
        }
        return text
    }
    private var suggestionMessage: String {
        guard let s = pendingSuggestion else { return "" }
        if s.suggestedKcal == nil { return l.t("confirm.suggestion.goal") }
        var text = targetIsVeterinarian ? l.t("confirm.vetFirst") : l.t("confirm.suggestion.message")
        if s.action == .switchToMaintenance { text += "\n\n" + l.t("confirm.suggestion.goal") }
        return text
    }
    /// Adopting a weight-loss estimate based on a BCS-estimated ideal weight also stores that ideal weight as "my estimate".
    private func storesEstimatedIdealWeight(_ e: EnergyEstimate) -> Bool {
        ProfileAdapter.hasIdealWeightSource && e.equation == .weightLossAaha && e.idealWeight?.source == .bcsEstimate
    }
    private func applyEstimate(_ e: EnergyEstimate) {
        guard let start = e.startKcal else { return }
        draft.targetKcal = targetKcal(from: start)
        draft.targetSource = .provisional
        if storesEstimatedIdealWeight(e), let ibw = e.idealWeight {
            draft.profile.idealWeightKg = (ibw.kg * 100).rounded() / 100
            ProfileAdapter.setIdealWeightSource(&draft.profile, .estimate)
        }
        pendingEstimate = nil
    }
    private func applySuggestion(_ s: Suggestion) {
        if let kcal = s.suggestedKcal {
            let newTarget = targetKcal(from: kcal)
            if newTarget != draft.targetKcal { draft.targetKcal = newTarget; draft.targetSource = .provisional }
        } else if s.action != .switchToMaintenance { return }
        if s.action == .switchToMaintenance { draft.goal = .maintain }
        pendingSuggestion = nil
    }

    // MARK: Save bar

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Theme.alert) }
            else if invalidFields.isEmpty, hasChanges, let message = validationError {
                Text(message).font(.caption).foregroundStyle(Theme.alert)
            }
            HStack {
                Button(l.t("editor.save")) {
                    do { try store.save(candidate); error = "" } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!invalidFields.isEmpty || !hasChanges)
                Button(l.t("editor.discard")) {
                    if let original = store.plan.cat(draft.id) {
                        draft = original; error = ""
                        ageMode = original.profile.birthDate != nil ? .birthDate : original.profile.approxAgeYears != nil ? .approximate : .unknown
                    }
                }
                .disabled(!hasChanges)
                if hasChanges { Text(l.t("editor.unsaved")).font(.caption).foregroundStyle(Theme.sakuraInk) }
                Spacer()
                Button(l.t("editor.removeCat"), role: .destructive) { confirmDelete = true }
                    .disabled(store.plan.cats.count <= 1)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    // MARK: Side panel

    @ViewBuilder private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                CatAvatar(id: draft.id, icon: draft.icon, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.name.isEmpty ? l.t("editor.unnamed") : draft.name).roundedHeading(.title2)
                    Text(l.t("editor.subtitle", ["weight": l.kg(draft.weightKg), "goal": l.goal(draft.goal)]))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            if let result = preview {
                if result.estimate.status == .refer {
                    EstimateSection(cat: draft, result: result, asOf: asOf)
                    PortionsSection(result: result, plan: candidate, showsKcal: false)
                } else {
                    EstimateSection(cat: draft, result: result, asOf: asOf) { pendingEstimate = result.estimate }
                        .stickerCard()
                    NutritionSection(nutrition: result.nutrition, plan: candidate).stickerCard()
                    PortionsSection(result: result, plan: candidate).stickerCard()
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l.t("editor.previewTitle")).roundedHeading(.headline)
                    Text(l.t("editor.invalidPreview")).foregroundStyle(Theme.muted)
                    if invalidFields.isEmpty, let message = validationError { Text(message).font(.caption).foregroundStyle(Theme.alert) }
                }
            }
        }
    }
}

/// The profile and plan form of the cat editor.
@MainActor
struct CatProfileForm: View {
    @Binding var draft: Cat
    @Binding var ageMode: AgeMode
    @Binding var invalidFields: Set<String>
    let plan: Plan
    let asOf: String
    @Environment(\.l10n) private var l

    private var profile: Profile { draft.profile }
    private var isKitten: Bool { ((try? Estimator.stageOf(draft, asOf: asOf)) ?? nil) == .kitten }
    private var reproductionRelevant: Bool {
        (profile.sex != .male && profile.neutered != .yes) || profile.reproduction.status != .none
    }

    var body: some View {
        Form {
            basics
            age
            sexAndNeutering
            lifestyle
            condition
            weights
            if reproductionRelevant { reproduction }
            health
            target
            meals
            balance
        }
        .formStyle(.grouped)
    }

    private var basics: some View {
        Section(l.t("editor.section.basics")) {
            TextField(l.t("field.name"), text: $draft.name)
            LabeledContent(l.t("icon.legend")) { CatIconPicker(selection: $draft.icon) }
            NumberEntry(label: l.t("field.weightKg"), key: "weight", value: $draft.weightKg, invalidFields: $invalidFields, maxDecimals: 3)
            Picker(l.t("field.goal"), selection: $draft.goal) { ForEach(Goal.allCases, id: \.self) { Text(l.goal($0)).tag($0) } }
        }
    }

    private var age: some View {
        Section(l.t("editor.section.age")) {
            Picker(l.t("field.ageKnownAs"), selection: $ageMode) {
                Text(l.t("age.birthDate")).tag(AgeMode.birthDate)
                Text(l.t("age.approximate")).tag(AgeMode.approximate)
                Text(l.t("age.unknown")).tag(AgeMode.unknown)
            }
            .onChange(of: ageMode) { _, mode in
                switch mode {
                case .birthDate:
                    if draft.profile.birthDate == nil, let years = draft.profile.approxAgeYears {
                        draft.profile.birthDate = ISODate.adding(days: -Int((years * EnergyModel.Units.daysPerYear).rounded()), to: asOf)
                    }
                    draft.profile.approxAgeYears = nil
                case .approximate: draft.profile.birthDate = nil
                case .unknown: draft.profile.birthDate = nil; draft.profile.approxAgeYears = nil
                }
            }
            if ageMode == .birthDate {
                DatePicker(l.t("field.birthDate"), selection: isoDate(\.birthDate), in: ...Date(), displayedComponents: .date)
                if profile.birthDate == nil { Text(l.t("age.pickDate")).font(.caption).foregroundStyle(Theme.muted) }
            } else if ageMode == .approximate {
                OptionalNumberEntry(label: l.t("field.approxAge"), key: "approx-age", value: $draft.profile.approxAgeYears, invalidFields: $invalidFields)
            }
        }
    }

    private var sexAndNeutering: some View {
        Section(l.t("editor.section.sex")) {
            Picker(l.t("field.sex"), selection: $draft.profile.sex) { ForEach(Sex.allCases, id: \.self) { Text(l.sex($0)).tag($0) } }
            Picker(l.t("field.neutered"), selection: $draft.profile.neutered) {
                ForEach(Neutered.allCases, id: \.self) { Text(l.neutered($0)).tag($0) }
            }
            if profile.neutered == .yes {
                Toggle(l.t("field.knowNeuterDate"), isOn: Binding(
                    get: { draft.profile.neuteredDate != nil },
                    set: { draft.profile.neuteredDate = $0 ? (draft.profile.neuteredDate ?? asOf) : nil }))
                if profile.neuteredDate != nil {
                    DatePicker(l.t("field.neuterDate"), selection: isoDate(\.neuteredDate), in: ...Date(), displayedComponents: .date)
                }
            }
        }
    }

    private var lifestyle: some View {
        Section(l.t("editor.section.lifestyle")) {
            Picker(l.t("field.lifestyle"), selection: $draft.profile.lifestyle) {
                Text(l.t("lifestyle.default")).tag(Lifestyle?.none)
                ForEach(Lifestyle.allCases, id: \.self) { Text(l.lifestyle($0)).tag(Lifestyle?.some($0)) }
            }
            Text(profile.lifestyle.map { l.lifestyleDescription($0) } ?? l.t("lifestyle.default.description"))
                .font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var condition: some View {
        Section(l.t("editor.section.condition")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(l.t("field.bcs"))
                Picker(l.t("field.bcs"), selection: $draft.profile.bcs) {
                    Text("?").tag(Int?.none)
                    ForEach(1...9, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                }
                .pickerStyle(.segmented).labelsHidden()
                Text(profile.bcs.map { l.bcsDescription($0) } ?? l.t("bcs.unknown")).font(.caption).foregroundStyle(Theme.muted)
            }
            Picker(l.t("field.mcs"), selection: $draft.profile.mcs) {
                Text(l.t("mcs.none")).tag(MuscleCondition?.none)
                ForEach(MuscleCondition.allCases, id: \.self) { Text(l.mcs($0)).tag(MuscleCondition?.some($0)) }
            }
            Text(l.t("mcs.help")).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var weights: some View {
        Section(l.t("editor.section.weights")) {
            OptionalNumberEntry(label: ProfileAdapter.hasIdealWeightSource ? l.t("field.idealWeight") : l.t("field.idealWeightVet"),
                                key: "ideal", value: $draft.profile.idealWeightKg, invalidFields: $invalidFields, maxDecimals: 3)
                .onChange(of: draft.profile.idealWeightKg) { _, kg in
                    // Entering an ideal weight by hand means it comes from the veterinarian; clearing it clears the source.
                    if kg == nil { ProfileAdapter.setIdealWeightSource(&draft.profile, nil) }
                    else if ProfileAdapter.idealWeightSource(draft.profile) == nil { ProfileAdapter.setIdealWeightSource(&draft.profile, .veterinarian) }
                }
            if ProfileAdapter.hasIdealWeightSource, profile.idealWeightKg != nil {
                Picker(l.t("field.idealWeightSource"), selection: Binding(
                    get: { ProfileAdapter.idealWeightSource(draft.profile) ?? .veterinarian },
                    set: { ProfileAdapter.setIdealWeightSource(&draft.profile, $0) })) {
                    Text(l.t("idealSource.veterinarian")).tag(IdealWeightSourceChoice.veterinarian)
                    Text(l.t("idealSource.estimate")).tag(IdealWeightSourceChoice.estimate)
                }
                if ProfileAdapter.idealWeightSource(profile) == .estimate {
                    Button(l.t("field.reestimate")) {
                        draft.profile.idealWeightKg = nil
                        ProfileAdapter.setIdealWeightSource(&draft.profile, nil)
                    }
                }
            }
            Text(l.t("field.idealWeightHelp")).font(.caption).foregroundStyle(Theme.muted)
            if isKitten {
                OptionalNumberEntry(label: l.t("field.expectedAdult"), key: "adult", value: $draft.profile.expectedAdultWeightKg,
                                    invalidFields: $invalidFields, maxDecimals: 3)
            }
        }
    }

    private var reproduction: some View {
        Section(l.t("editor.section.reproduction")) {
            Picker(l.t("field.reproduction"), selection: $draft.profile.reproduction.status) {
                ForEach(ReproductionStatus.allCases, id: \.self) { Text(l.reproduction($0)).tag($0) }
            }
            if profile.reproduction.status == .gestation {
                OptionalNumberEntry(label: l.t("field.preBreeding"), key: "pre-breeding",
                                    value: $draft.profile.reproduction.preBreedingWeightKg, invalidFields: $invalidFields, maxDecimals: 3)
            }
            if profile.reproduction.status == .lactation {
                OptionalIntPicker(label: l.t("field.litterSize"), range: 1...12, value: $draft.profile.reproduction.litterSize)
                OptionalIntPicker(label: l.t("field.lactationWeek"), range: 1...12, value: $draft.profile.reproduction.lactationWeek)
            }
        }
    }

    private var health: some View {
        Section(l.t("editor.section.health")) {
            Text(l.t("health.chronic")).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            ForEach(MedicalFlag.allCases.filter { !$0.isAcute }, id: \.self) { flag in Toggle(l.medical(flag), isOn: medical(flag)) }
            Text(l.t("health.acute")).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            ForEach(MedicalFlag.allCases.filter(\.isAcute), id: \.self) { flag in Toggle(l.medical(flag), isOn: medical(flag)) }
            Toggle(l.t("field.endOfLife"), isOn: $draft.profile.endOfLife)
            OptionalNumberEntry(label: l.t("field.verifiedIntake"), key: "verified", value: $draft.profile.verifiedIntakeKcal,
                                invalidFields: $invalidFields)
            Text(l.t("field.verifiedIntakeHelp")).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var target: some View {
        Section(l.t("editor.section.target")) {
            NumberEntry(label: l.t("field.target"), key: "target", value: $draft.targetKcal, invalidFields: $invalidFields)
            Picker(l.t("field.targetSource"), selection: $draft.targetSource) {
                ForEach(TargetSource.allCases, id: \.self) { Text(l.targetSource($0)).tag($0) }
            }
            NumberEntry(label: l.t("field.extras"), key: "extras", value: $draft.extraKcal, invalidFields: $invalidFields)
            Text(l.t("field.targetHelp")).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var meals: some View {
        Section(l.t("editor.section.meals")) {
            ForEach(draft.meals) { row in
                let meal = elementBinding($draft.meals, id: row.id, fallback: row)
                VStack(alignment: .leading, spacing: 8) {
                    TextField(l.t("field.mealLabel"), text: meal.label)
                    Picker(l.t("field.food"), selection: meal.foodId) {
                        ForEach(plan.foods) { food in Text(food.name).tag(food.id) }
                    }
                    NumberEntry(label: l.t("field.gramsEaten"), key: row.id, value: meal.grams, invalidFields: $invalidFields)
                    Button(l.t("editor.removeMeal"), role: .destructive) { draft.meals.removeAll { $0.id == row.id } }
                        .font(.caption)
                }
                .padding(.vertical, 5)
            }
            Button(l.t("editor.addMeal"), systemImage: "plus") {
                guard let food = plan.foods.first else { return }
                draft.meals.append(Meal(id: newId("meal"), label: l.t("editor.newMeal"), foodId: food.id, grams: 0))
            }
            .disabled(draft.meals.count >= 24)
            Text(l.t("editor.mealsHelp")).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var balance: some View {
        Section(l.t("editor.section.balance")) {
            Picker(l.t("field.balanceFood"), selection: $draft.balanceFoodId) {
                ForEach(plan.foods) { food in Text(food.name).tag(food.id) }
            }
            Text(l.t("editor.balanceHelp")).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    // MARK: Bindings

    private func medical(_ flag: MedicalFlag) -> Binding<Bool> {
        Binding(get: { draft.profile.medical.contains(flag) }, set: { on in
            var flags = Set(draft.profile.medical)
            if on { flags.insert(flag) } else { flags.remove(flag) }
            draft.profile.medical = MedicalFlag.allCases.filter { flags.contains($0) }
        })
    }
    /// A date picker binding for an optional `YYYY-MM-DD` profile field; shows today while unset.
    private func isoDate(_ keyPath: WritableKeyPath<Profile, String?>) -> Binding<Date> {
        Binding(get: { draft.profile[keyPath: keyPath].flatMap(ISODate.date) ?? ISODate.today() },
                set: { draft.profile[keyPath: keyPath] = ISODate.string($0) })
    }
}
