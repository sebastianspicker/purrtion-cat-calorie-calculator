import SwiftUI
import PurrtionCore

@MainActor
struct MethodView: View {
    let store: PlanStore
    @State private var showReset = false
    @Environment(\.l10n) private var l
    private typealias M = EnergyModel

    private func c(_ value: Double) -> String { l.num(value, digits: 4) }
    private var allocationFormulas: String {
        """
        E fixed = Σ (\(l.t("method.f.gramsEaten")) × kcal/g)
        E balance = max(0, \(l.t("method.f.target")) − E fixed − E extras)
        g balance = E balance ÷ kcal/g
        1 kcal = \(c(M.Units.kjPerKcal)) kJ
        """
    }
    private var estimateFormulas: String {
        """
        RER = \(c(M.Rer.factor)) × BW^\(c(M.Rer.exponent))
        MER = k × W^\(c(M.Mer.exponent)),  k = \(c(M.Mer.sedentary)) / \(c(M.Mer.typical)) / \(c(M.Mer.active))
        IBW = BW ÷ (1 + \(c(M.IdealWeight.fractionPerBcsUnit)) × (BCS − \(Int(M.Bcs.ideal)))),  BCS ≥ \(Int(M.Bcs.overweightMin))
        \(l.t("why.word.start")) (\(l.goal(.loss))) = max(\(l.t("why.word.floor")), \(c(M.Loss.startFactor)) × min(RER(IBW), MER(k, IBW)))
        V: \(l.t("why.word.start")) = max(\(l.t("why.word.floor")), \(c(M.Loss.verifiedIntakeFactor)) × V),  V ≥ \(l.t("why.word.floor"))
        \(l.t("why.word.floor")) = \(c(M.Floor.rerFactor)) × RER(IBW)
        """
    }
    private var foodFormulas: String {
        """
        NFE = max(0, 100 − M − P − F − CF − A)
        GE = \(c(M.Food.geProtein))P + \(c(M.Food.geFat))F + \(c(M.Food.geCarbohydrate))(NFE + CF)
        d = \(c(M.Food.digestibilityIntercept)) − \(c(M.Food.digestibilityFibreSlope)) × 100 CF ÷ (100 − M)
        ME = GE × d ÷ 100 − \(c(M.Food.proteinCorrection))P
        ME Atwater = \(c(M.Food.atwaterProtein))P + \(c(M.Food.atwaterFat))F + \(c(M.Food.atwaterNfe)) NFE
        """
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    CatFace(size: 56, expression: .thinking, hat: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.t("method.title")).roundedHeading(.largeTitle)
                        Text(l.t("method.subtitle")).foregroundStyle(Theme.muted)
                    }
                }
                section(l.t("method.allocation"), formula: allocationFormulas, texts: ["method.allocationText1", "method.allocationText2"])
                section(l.t("method.estimate"), formula: estimateFormulas, texts: ["method.estimateText1", "method.estimateText2"])
                section(l.t("method.food"), formula: foodFormulas, texts: ["method.foodText"])
                section(l.t("method.limits"), formula: nil, texts: ["method.limitsText1", "method.limitsText2", "method.limitsText3"])
                storage
                Text(l.t("method.reading")).font(.headline)
                Link(l.t("method.link.merck"), destination: URL(string: "https://www.merckvetmanual.com/management-and-nutrition/nutrition-small-animals/nutritional-requirements-of-small-animals")!)
                Link(l.t("method.link.aaha"), destination: URL(string: "https://www.aaha.org/resources/2021-aaha-nutrition-and-weight-management-guidelines/prevention-of-obesity/")!)
                Text(l.t("method.linksNote")).font(.caption).foregroundStyle(Theme.muted)
            }
            .font(.callout).padding(28).frame(maxWidth: 1000, alignment: .leading)
        }
        .background(Theme.paper)
        .confirmationDialog(l.t("method.resetTitle"), isPresented: $showReset, titleVisibility: .visible) {
            Button(l.t("method.reset"), role: .destructive) { do { try store.reset() } catch { store.errorMessage = error.localizedDescription } }
            Button(l.t("common.cancel"), role: .cancel) { }
        } message: { Text(l.t("method.resetMessage")) }
    }

    private func section(_ title: String, formula: String?, texts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).roundedHeading(.title3)
            if let formula {
                Text(formula).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
            }
            ForEach(texts, id: \.self) { key in Text(l.t(key)).fixedSize(horizontal: false, vertical: true) }
        }
        .stickerCard()
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.t("method.storage")).roundedHeading(.title3)
            Text(l.t("method.storageText1"))
            Text(l.t("method.storageText2"))
            Text(store.storageURL.path).font(.caption).textSelection(.enabled)
            Button(l.t("method.resetButton"), role: .destructive) { showReset = true }
        }
        .stickerCard()
    }
}
