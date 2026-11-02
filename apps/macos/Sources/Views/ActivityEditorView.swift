import SwiftUI
import PurrtionCore

@MainActor
struct ActivityEditorView: View {
    let store: PlanStore
    @State private var activities: [Activity]
    @State private var invalidFields = Set<String>()
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l
    init(store: PlanStore) { self.store = store; _activities = State(initialValue: store.plan.activities) }
    private var total: Double { activities.reduce(0) { $0 + $1.sharePercent } }
    var body: some View {
        Form {
            Section(l.t("activities.title")) {
                Text(l.t("activities.help")).font(.caption).foregroundStyle(Theme.muted)
                ForEach(activities) { row in
                    let activity = elementBinding($activities, id: row.id, fallback: row)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(l.t("activities.label"), text: activity.label)
                        NumberEntry(label: l.t("activities.share"), key: row.id, value: activity.sharePercent, invalidFields: $invalidFields)
                        Button(l.t("common.remove"), role: .destructive) { activities.removeAll { $0.id == row.id } }.font(.caption)
                    }.padding(.vertical, 6)
                }
                Button(l.t("activities.add"), systemImage: "plus") {
                    activities.append(Activity(id: newId("activity"), label: l.t("activities.new"), sharePercent: 0))
                }.disabled(activities.count >= 12)
                Text(l.t("activities.total", ["percent": l.percent(total, digits: 2)])).monospacedDigit()
            }
            Section {
                if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Theme.alert) }
                HStack {
                    Button(l.t("activities.save")) {
                        var plan = store.plan; plan.activities = activities
                        do { try store.save(plan); dismiss() } catch { self.error = error.localizedDescription }
                    }.buttonStyle(.borderedProminent).tint(Theme.sakuraInk).disabled(!invalidFields.isEmpty || abs(total - 100) > 1e-6)
                    Button(l.t("common.cancel")) { dismiss() }
                }
            }
        }.formStyle(.grouped).frame(width: 540, height: 560)
    }
}
