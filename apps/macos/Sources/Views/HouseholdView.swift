import SwiftUI
import PurrtionCore

@MainActor
struct HouseholdView: View {
    let store: PlanStore
    let selectCat: (String) -> Void
    @Environment(\.l10n) private var l

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(l.t("household.intro")).foregroundStyle(Theme.muted)
                if let result = store.result {
                    catCards(result)
                    prepareToday(result)
                    mealSchedule
                    activities(result)
                    assumptions(result)
                } else {
                    ContentUnavailableView(l.t("household.invalidTitle"), systemImage: "exclamationmark.triangle",
                                           description: Text(l.t("household.invalidText")))
                }
            }
            .padding(26)
        }
        .background(Theme.paper)
    }

    private func catCards(_ result: PlanResult) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 18)], alignment: .leading, spacing: 18) {
            ForEach(result.cats) { row in
                if let cat = store.plan.cat(row.id) {
                    Button { selectCat(cat.id) } label: { catCard(cat, row) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(l.t("household.cardLabel", ["name": cat.name, "grams": l.int(row.balanceGramsRounded),
                                                                         "food": store.plan.foodName(row.balanceFoodId)]))
                }
            }
        }
    }

    private func catCard(_ cat: Cat, _ row: CatResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CatAvatar(id: cat.id, icon: cat.icon, size: 40)
                Text(cat.name).roundedHeading(.title3).lineLimit(1)
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(l.int(row.balanceGramsRounded)).bigNumber(size: 44)
                Text("g").font(.title3).foregroundStyle(Theme.muted)
            }
            Text(store.plan.foodName(row.balanceFoodId)).font(.callout)
            Chip(text: l.status(row.estimate.status), tone: statusTone(row.estimate.status))
        }
        .stickerCard()
        .contentShape(Rectangle())
    }

    private func prepareToday(_ result: PlanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.t("household.prepare")).roundedHeading(.title3)
            ForEach(result.totals.balanceByFood, id: \.foodId) { item in
                HStack(alignment: .firstTextBaseline) {
                    Text(store.plan.foodName(item.foodId))
                    Spacer()
                    Text("\(l.int(item.gramsRounded)) g").bigNumber(size: 22)
                }
            }
            if result.totals.fixedGrams > 0 {
                HStack(alignment: .firstTextBaseline) {
                    Text(l.t("household.fixedTotal"))
                    Spacer()
                    Text(l.grams(result.totals.fixedGrams)).monospacedDigit()
                }
                .foregroundStyle(Theme.muted)
            }
            Text(l.t("household.prepareHelp")).font(.caption).foregroundStyle(Theme.muted)
        }
        .stickerCard()
    }

    private var mealSchedule: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.t("household.meals")).roundedHeading(.title3)
            ForEach(store.plan.cats) { cat in
                VStack(alignment: .leading, spacing: 6) {
                    Text(cat.name).font(.headline)
                    if cat.meals.isEmpty {
                        Text(l.t("household.noMeals")).font(.caption).foregroundStyle(Theme.muted)
                    }
                    ForEach(cat.meals) { meal in
                        HStack {
                            Text(meal.label).frame(width: 140, alignment: .leading)
                            Text(store.plan.foodName(meal.foodId))
                            Spacer()
                            Text(l.t("household.gramsEaten", ["grams": l.num(meal.grams)])).monospacedDigit()
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .stickerCard()
    }

    private func activities(_ result: PlanResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.t("household.activities")).roundedHeading(.title3)
            ForEach(result.cats) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.plan.cat(row.id)?.name ?? row.id).font(.headline)
                    ForEach(row.activities) { activity in
                        HStack { Text(activity.label); Spacer(); Text("\(l.int(activity.roundedGrams)) g").monospacedDigit() }
                            .font(.callout)
                    }
                }
            }
            Text(l.t("household.activitiesHelp")).font(.caption).foregroundStyle(Theme.muted)
        }
        .stickerCard()
    }

    @ViewBuilder private func assumptions(_ result: PlanResult) -> some View {
        let codes = Array(Set(result.cats.flatMap(\.warnings))).sorted { $0.rawValue < $1.rawValue }
        if !codes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(l.t("household.assumptions")).font(.headline)
                ForEach(codes, id: \.self) { code in
                    WarningLine(text: code.message(locale: l.language), tint: code == .overBudget ? Theme.alert : Theme.muted,
                                icon: code == .overBudget ? "exclamationmark.triangle" : "info.circle")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
