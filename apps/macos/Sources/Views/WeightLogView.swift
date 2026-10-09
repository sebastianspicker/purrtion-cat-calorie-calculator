import SwiftUI
import Charts
import PurrtionCore

/// Weigh-ins, the weight chart and the monitoring suggestion (ENGINE.md §6). Edits the cat draft; the editor saves.
struct WeightLogView: View {
    @Binding var cat: Cat
    let result: CatResult?
    let onApplySuggestion: (Suggestion) -> Void
    @State private var newDate = ISODate.today()
    @State private var newWeight: Double?
    @State private var newBcs: Int?
    @State private var invalidFields = Set<String>()
    @State private var confirmReplace = false
    @Environment(\.l10n) private var l

    private struct Point: Identifiable { let id: String; let date: Date; let kg: Double }
    private var points: [Point] {
        cat.weightLog.compactMap { entry in ISODate.date(entry.date).map { Point(id: entry.id, date: $0, kg: entry.weightKg) } }
            .sorted { $0.date < $1.date }
    }
    private var idealKg: Double? {
        if let ibw = result?.estimate.idealWeight, ibw.source != .current { return ibw.kg }
        return cat.profile.idealWeightKg
    }
    private var weightIsValid: Bool { newWeight.map { $0 >= 0.1 && $0 <= 40 } ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                addCard
                if !points.isEmpty { chartCard }
                trendCard
                entriesCard
            }
            .padding(20)
        }
    }

    private var replacesEntry: Bool { cat.weightLog.contains { $0.date == ISODate.string(newDate) } }
    private func addWeighIn() {
        guard let weight = newWeight, weightIsValid else { return }
        cat.addWeighIn(date: ISODate.string(newDate), weightKg: weight, bcs: newBcs)
        newWeight = nil; newBcs = nil
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.t("weights.add")).roundedHeading(.headline)
            HStack(alignment: .top, spacing: 14) {
                DatePicker(l.t("weights.date"), selection: $newDate, in: ...Date(), displayedComponents: .date)
                    .frame(maxWidth: 240)
                OptionalNumberEntry(label: l.t("weights.weightKg"), key: "new-weight", value: $newWeight, invalidFields: $invalidFields, maxDecimals: 3)
                    .frame(maxWidth: 140)
                OptionalIntPicker(label: l.t("weights.bcs"), range: 1...9, value: $newBcs).frame(maxWidth: 180)
            }
            HStack {
                Button(l.t("weights.addButton"), systemImage: "plus") {
                    guard weightIsValid else { return }
                    if replacesEntry { confirmReplace = true } else { addWeighIn() }
                }
                .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                .disabled(!weightIsValid || !invalidFields.isEmpty || (cat.weightLog.count >= 1000 && !replacesEntry))
                .confirmationDialog(l.t("weights.replaceTitle"), isPresented: $confirmReplace, titleVisibility: .visible) {
                    Button(l.t("weights.replaceButton")) { addWeighIn() }
                    Button(l.t("common.cancel"), role: .cancel) { }
                } message: { Text(l.t("weights.replaceMessage", ["date": l.date(ISODate.string(newDate))])) }
                Text(l.t("weights.addHint")).font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .stickerCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.t("weights.chartTitle")).roundedHeading(.headline)
            let weights = points.map(\.kg) + (idealKg.map { [$0] } ?? [])
            let lo = max(0, ((weights.min() ?? 0) - 0.3) * 10).rounded(.down) / 10
            let hi = (((weights.max() ?? 1) + 0.3) * 10).rounded(.up) / 10
            Chart {
                ForEach(points) { point in
                    LineMark(x: .value(l.t("weights.date"), point.date, unit: .day), y: .value(l.t("weights.weightKg"), point.kg))
                        .foregroundStyle(Theme.sakuraInk)
                    PointMark(x: .value(l.t("weights.date"), point.date, unit: .day), y: .value(l.t("weights.weightKg"), point.kg))
                        .foregroundStyle(Theme.sakura)
                }
                if let ideal = idealKg {
                    RuleMark(y: .value(l.t("weights.ideal"), ideal))
                        .foregroundStyle(Theme.matchaInk)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(l.t("weights.idealLabel", ["kg": l.kg(ideal)])).font(.caption2).foregroundStyle(Theme.matchaInk)
                        }
                }
            }
            .chartYScale(domain: lo...max(hi, lo + 0.2))
            .frame(height: 220)
            .accessibilityLabel(l.t("weights.chartTitle"))
        }
        .stickerCard()
    }

    @ViewBuilder private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.t("trend.title")).roundedHeading(.headline)
            if let trend = result?.trend {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                    GridRow { Text(l.t("trend.entries")).foregroundStyle(Theme.muted); Text(l.int(trend.entries)) }
                    if let latest = trend.latestKg {
                        GridRow { Text(l.t("trend.latest")).foregroundStyle(Theme.muted); Text(l.kg(latest)) }
                    }
                    GridRow {
                        Text(l.t("trend.rate")).foregroundStyle(Theme.muted)
                        Text(trend.ratePercentPerWeek.map { l.t("trend.ratePerWeek", ["rate": l.signedPercent($0, digits: 2)]) } ?? l.t("trend.notEnough"))
                    }
                    GridRow {
                        Text(l.t("trend.change28")).foregroundStyle(Theme.muted)
                        Text(trend.change28dPercent.map { l.signedPercent($0) } ?? l.t("trend.notEnough"))
                    }
                    GridRow { Text(l.t("trend.nextWeighIn")).foregroundStyle(Theme.muted); Text(nextWeighIn(trend)) }
                }
                .font(.callout).monospacedDigit()
                suggestion(trend.suggestion)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.t("trend.adviceOncePerTwoWeeks"))
                    Text(l.t("trend.adviceSecondPlateau"))
                }
                .font(.caption).foregroundStyle(Theme.muted)
            } else {
                Text(l.t("editor.invalidPreview")).foregroundStyle(Theme.muted)
            }
        }
        .stickerCard()
    }

    @ViewBuilder private func suggestion(_ suggestion: Suggestion?) -> some View {
        if let s = suggestion {
            VStack(alignment: .leading, spacing: 6) {
                Text(l.msg("action.\(s.action.rawValue)")).font(.headline).fontDesign(.rounded)
                Text(l.msg("reason.\(s.reason.rawValue)")).font(.callout)
                if let kcal = s.suggestedKcal {
                    Text(l.t("trend.suggested", ["kcal": l.int(kcal)])).font(.callout).monospacedDigit()
                    Button(l.t("trend.apply"), systemImage: "pawprint") { onApplySuggestion(s) }
                        .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                        .disabled(targetKcal(from: kcal) == cat.targetKcal && !(s.action == .switchToMaintenance && cat.goal != .maintain))
                } else if s.action == .switchToMaintenance, cat.goal != .maintain {
                    Button(l.t("trend.switchGoal"), systemImage: "pawprint") { onApplySuggestion(s) }
                        .buttonStyle(.borderedProminent).tint(Theme.sakuraInk)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.sky.opacity(0.15)))
        } else {
            Text(l.t("trend.noSuggestion")).font(.callout).foregroundStyle(Theme.muted)
        }
    }

    private func nextWeighIn(_ trend: Trend) -> String {
        let today = Dates.todayLocal()
        let latest = cat.weightLog.map(\.date).filter { $0 <= today }.max() ?? today
        let date = ISODate.adding(days: trend.nextWeighInDays, to: latest) ?? today
        return l.date(date)
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.t("weights.entries")).roundedHeading(.headline)
            if cat.weightLog.isEmpty {
                Text(l.t("weights.empty")).foregroundStyle(Theme.muted)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        Text(l.t("weights.date")); Text(l.t("weights.weightKg")); Text(l.t("weights.bcs")); Text("")
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    ForEach(cat.weightLog.sorted { $0.date != $1.date ? $0.date > $1.date : $0.id > $1.id }) { entry in
                        GridRow {
                            Text(l.date(entry.date))
                            Text(l.kg(entry.weightKg)).monospacedDigit()
                            Text(entry.bcs.map { l.int($0) } ?? "–").monospacedDigit()
                            Button(l.t("common.remove"), role: .destructive) { cat.weightLog.removeAll { $0.id == entry.id } }
                                .buttonStyle(.borderless).font(.caption)
                        }
                    }
                }
            }
        }
        .stickerCard()
    }
}
