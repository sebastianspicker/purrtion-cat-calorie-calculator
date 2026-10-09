import SwiftUI

@MainActor
struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.system(size: 34, weight: .medium, design: .rounded)).monospacedDigit()
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
    }
}
