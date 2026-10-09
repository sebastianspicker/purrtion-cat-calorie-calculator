import SwiftUI
import PurrtionCore

/// Plain referral panel: plain icon and words, no kcal numbers, no mascot.
struct ReferralPanel: View {
    let reasons: [ReferCode]
    @Environment(\.l10n) private var l
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(l.t("refer.title"), systemImage: "stethoscope").font(.headline)
            Text(l.t("refer.intro"))
            ForEach(reasons, id: \.self) { code in
                Label(l.msg("refer.\(code.rawValue)"), systemImage: "circle.fill")
                    .labelStyle(BulletLabelStyle())
            }
            Text(l.t("refer.outro")).font(.callout)
        }
        .plainPanel(tint: Theme.alert)
        .accessibilityElement(children: .combine)
    }
}

/// A small bullet before wrapped text.
struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
            configuration.title.fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A plain warning line (icon + text) for comparisons, warnings and food checks.
struct WarningLine: View {
    let text: String
    var tint: Color = Theme.yolkInk
    var icon = "exclamationmark.triangle"
    var body: some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: icon).foregroundStyle(tint) }
            .font(.callout)
    }
}

/// Equation and source chips.
struct EquationChips: View {
    let equation: String
    @Environment(\.l10n) private var l
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chip(text: l.msg("equation.\(equation)"), tone: .sky)
            let refs = Formulas.citation(equation)
            if !refs.isEmpty { Chip(text: l.t("estimate.sources", ["refs": refs])) }
        }
    }
}

/// Estimator output for one cat (ENGINE.md §3). Never writes the target; "Use estimate" is a callback that confirms first.
struct EstimateSection: View {
    let cat: Cat
    let result: CatResult
    let asOf: String
    var showsComparison = true
    var useEstimate: (() -> Void)? = nil
    @Environment(\.l10n) private var l

    private var e: EnergyEstimate { result.estimate }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.t("estimate.title")).roundedHeading(.title3)
            chips
            if e.status == .refer {
                ReferralPanel(reasons: e.reasons)
            } else if e.status == .needsInput || e.startKcal == nil {
                needsInput
            } else {
                figure
            }
        }
    }

    private var chips: some View {
        HStack(spacing: 6) {
            Chip(text: l.status(e.status), tone: statusTone(e.status))
            if let stage = e.stage { Chip(text: l.stage(stage)) }
            if let label = e.lifeStageLabel, e.stage != .kitten { Chip(text: l.lifeStage(label)) }
        }
    }

    private var needsInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.t("estimate.needsInput"))
            ForEach(e.missing, id: \.self) { code in
                Label(l.msg("missing.\(code.rawValue)"), systemImage: "circle.fill").labelStyle(BulletLabelStyle())
            }
        }
        .stickerCard(fill: Theme.yolk.opacity(0.18), padding: 12)
    }

    @ViewBuilder private var figure: some View {
        let reference = e.status == .referenceOnly
        if reference {
            VStack(alignment: .leading, spacing: 4) {
                Label(l.t("estimate.referenceTitle"), systemImage: "stethoscope").font(.headline)
                Text(l.t("estimate.referenceBanner")).font(.callout)
            }
            .plainPanel(tint: Theme.skyInk)
        }
        if let start = e.startKcal, let low = e.lowKcal, let high = e.highKcal {
            VStack(alignment: .leading, spacing: 2) {
                Text(reference ? l.t("estimate.referenceValue") : l.t("estimate.start")).font(.caption).foregroundStyle(Theme.muted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(l.int(start)).bigNumber()
                    Text(l.t("unit.kcalPerDay")).foregroundStyle(Theme.muted)
                }
                Text(l.t("estimate.rangeText", ["low": l.int(low), "high": l.int(high)])).font(.callout).monospacedDigit()
            }
            EnergyRuler(data: RulerData(estimate: e, target: showsComparison ? cat.targetKcal : nil))
        }
        if let equation = e.equation { EquationChips(equation: equation.rawValue) }
        if showsComparison, let comparison = e.comparison { comparisonView(comparison) }
        if let useEstimate, e.status == .ok, let start = e.startKcal, targetKcal(from: start) != cat.targetKcal {
            Button(l.t("estimate.useAsTarget", ["kcal": l.int(start)]), systemImage: "pawprint", action: useEstimate)
                .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
        }
        if !e.notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(e.notes, id: \.self) { code in
                    Label(l.msg("note.\(code.rawValue)"), systemImage: "info.circle").font(.callout)
                }
            }
        }
        DisclosureGroup(l.t("why.title")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(l.t("why.intro")).font(.caption).foregroundStyle(Theme.muted)
                ForEach(Formulas.explain(cat, e, asOf: asOf, l: l)) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.text).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if let caption = line.caption { Text(caption).font(.caption).foregroundStyle(Theme.muted) }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder private func comparisonView(_ c: Comparison) -> some View {
        if c.belowFloor {
            VStack(alignment: .leading, spacing: 4) {
                Label(l.t("comparison.belowFloorTitle"), systemImage: "exclamationmark.octagon.fill")
                    .font(.headline).foregroundStyle(Theme.alert)
                Text(l.msg("comparison.below-floor"))
            }
            .plainPanel(tint: Theme.alert)
        }
        Text(l.t("comparison.ratio", ["target": l.int(cat.targetKcal), "percent": l.int(c.targetToStartRatio * 100)]))
            .font(.callout).monospacedDigit()
        if c.belowRange && !c.belowFloor { WarningLine(text: l.msg("comparison.below-range")) }
        if c.aboveRange { WarningLine(text: l.msg("comparison.above-range")) }
        if c.differsOver30Percent { WarningLine(text: l.msg("comparison.differs-over-30-percent")) }
    }
}

func statusTone(_ status: EstimateStatus) -> ChipTone {
    if status == .ok { return .matcha }
    if status == .referenceOnly { return .sky }
    if status == .refer { return .alert }
    return .yolk
}

/// Nutrient checks (ENGINE.md §7). Unknown statuses are shown as "no nutrition check".
struct NutritionSection: View {
    let nutrition: NutritionResult
    let plan: Plan
    @Environment(\.l10n) private var l
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.t("nutrition.title")).roundedHeading(.headline)
            if case .ok(let n) = nutrition {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    row(l.t("nutrition.protein"), l.grams(n.proteinG))
                    row(l.t("nutrition.proteinPer1000"), "\(l.num(n.proteinPer1000)) g")
                    row(l.t("nutrition.minimum"), "\(l.num(n.minProteinPer1000)) g")
                    row(l.t("nutrition.carbs"), l.percent(n.carbPercentME))
                }
                .font(.callout)
                if n.warnings.isEmpty {
                    Label(l.msg("nutrition.ok"), systemImage: "checkmark.circle").foregroundStyle(Theme.matchaInk).font(.callout)
                }
                ForEach(n.warnings, id: \.self) { code in WarningLine(text: l.msg("nutrition.\(code.rawValue)")) }
                ForEach(n.notes, id: \.self) { code in
                    Text(l.msg("nutrition.\(code.rawValue)")).font(.callout).foregroundStyle(Theme.muted)
                }
            } else if case .incompleteData(let ids) = nutrition {
                Text(l.msg("nutrition.incomplete-data")).font(.callout).foregroundStyle(Theme.muted)
                if !ids.isEmpty {
                    Text(l.t("nutrition.missingFoods", ["foods": ids.map(plan.foodName).joined(separator: ", ")]))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            } else {
                Text(l.t("nutrition.notApplicable")).font(.callout).foregroundStyle(Theme.muted)
            }
        }
    }
    private func row(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(Theme.muted); Text(value).monospacedDigit() }
    }
}

/// Today's portions for one cat. With `showsKcal == false` (referral) only grams are shown.
struct PortionsSection: View {
    let result: CatResult
    let plan: Plan
    var showsKcal = true
    @Environment(\.l10n) private var l
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.t("portions.title")).roundedHeading(.headline)
            Text(l.t("portions.balancePerDay", ["food": plan.foodName(result.balanceFoodId)])).font(.caption).foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(l.int(result.balanceGramsRounded)).bigNumber(size: 40)
                Text("g").font(.title3).foregroundStyle(Theme.muted)
            }
            Text(l.t("portions.calculated", ["grams": l.fixed(result.balanceGramsExact, 2)])).font(.caption).monospacedDigit()
            if showsKcal {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    row(l.t("portions.fixed"), "\(l.grams(result.fixedGrams)), \(l.num(result.fixedKcal)) kcal")
                    row(l.t("portions.extras"), "\(l.num(result.extraKcal)) kcal")
                    row(l.t("portions.balanceKcal"), "\(l.num(result.balanceKcal)) kcal")
                    row(l.t("portions.afterRounding"), "\(l.num(result.roundedDailyKcal)) \(l.t("unit.kcalPerDay"))")
                }
                .font(.callout)
                if result.overBudgetKcal > 0 {
                    WarningLine(text: l.t("portions.overBudget", ["kcal": l.num(result.overBudgetKcal)]), tint: Theme.alert)
                }
            }
            if !result.activities.isEmpty {
                Divider()
                ForEach(result.activities) { activity in
                    HStack { Text(activity.label); Spacer(); Text("\(l.int(activity.roundedGrams)) g").monospacedDigit() }.font(.callout)
                }
            }
            if showsKcal {
                ForEach(result.warnings, id: \.self) { code in
                    WarningLine(text: code.message(locale: l.language), tint: code == .overBudget ? Theme.alert : Theme.muted,
                                icon: code == .overBudget ? "exclamationmark.triangle" : "info.circle")
                }
                DisclosureGroup(l.t("portions.rerTitle")) {
                    Text(l.t("portions.rerText", ["kcal": l.num(result.rerKcal)])).font(.caption).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                }
                .font(.callout)
            }
        }
    }
    private func row(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(Theme.muted); Text(value).monospacedDigit() }
    }
}
