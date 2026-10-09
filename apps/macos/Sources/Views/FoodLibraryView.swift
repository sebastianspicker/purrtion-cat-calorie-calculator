import SwiftUI
import PurrtionCore

@MainActor
struct FoodLibraryView: View {
    let store: PlanStore
    @State private var editing: Food?
    @Environment(\.l10n) private var l

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(l.t("foods.intro"), systemImage: "info.circle").font(.callout).foregroundStyle(Theme.muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 18)], alignment: .leading, spacing: 18) {
                    ForEach(store.plan.foods) { food in card(food) }
                }
                Button(l.t("foods.add"), systemImage: "plus") {
                    editing = Food(id: newId("food"), name: "", type: .wet, energyPerUnit: 100,
                                   energyUnit: .kcalPer100g, energySource: .label, completeness: .unknown)
                }
                .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                .disabled(store.plan.foods.count >= 100)
            }
            .padding(26)
        }
        .background(Theme.paper)
        .sheet(item: $editing) { food in FoodEditorView(store: store, initial: food) }
    }

    private func card(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(food.name).roundedHeading(.title3)
                Spacer()
                Button(l.t("common.edit")) { editing = food }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(food.displayEnergy.map { l.num($0) } ?? "–").bigNumber(size: 26)
                Text(food.energyUnit.rawValue).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 6) {
                Chip(text: l.foodType(food.type))
                Chip(text: l.energySource(food.energySource), tone: food.energySource == .label ? .matcha : .yolk)
                Chip(text: l.completeness(food.completeness), tone: food.completeness == .complete ? .matcha : .neutral)
            }
            Text(l.t("foods.lifeStage", ["claim": l.lifeStageClaim(food.lifeStageClaim)])).font(.caption).foregroundStyle(Theme.muted)
            if !food.note.isEmpty { Text(food.note).font(.caption).foregroundStyle(Theme.muted) }
        }
        .stickerCard()
    }
}
