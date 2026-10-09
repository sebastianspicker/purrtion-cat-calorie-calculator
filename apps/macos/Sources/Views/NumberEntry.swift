import SwiftUI
import Foundation

/// Parses a plain decimal with a point or comma, deliberately without thousands separators.
/// At most `maxDecimals` decimal places, so "1,200" in a kcal field is rejected instead of read as 1.2
/// (same rule as the website's `decimal()`).
func parseDecimal(_ text: String, maxDecimals: Int = 2) -> Double? {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let n = max(0, maxDecimals)
    let pattern = n == 0 ? "^[0-9]+[.,]?\\z" : "^([0-9]+([.,][0-9]{0,\(n)})?|[.,][0-9]{1,\(n)})\\z"
    guard cleaned.range(of: pattern, options: .regularExpression) != nil,
          let result = Double(cleaned.replacingOccurrences(of: ",", with: ".")), result.isFinite else { return nil }
    return result
}

/// Keeps incomplete/invalid text out of the calculation and disables saving via invalidFields.
@MainActor
struct NumberEntry: View {
    let label: String
    let key: String
    @Binding var value: Double
    @Binding var invalidFields: Set<String>
    var maxDecimals: Int = 2
    @State private var text = ""
    @Environment(\.l10n) private var l

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            TextField(label, text: $text)
                .monospacedDigit()
                .onAppear { text = l.plain(value) }
                .onChange(of: text) { _, new in
                    if let result = parseDecimal(new, maxDecimals: maxDecimals) { value = result; invalidFields.remove(key) }
                    else { invalidFields.insert(key) }
                }
                .onChange(of: value) { _, new in
                    if parseDecimal(text, maxDecimals: maxDecimals) != new { text = l.plain(new) }
                }
                .onDisappear { invalidFields.remove(key) }
            if invalidFields.contains(key) {
                Text(l.t("entry.invalidNumber")).font(.caption2).foregroundStyle(Theme.alert)
            }
        }
    }
}

/// Like NumberEntry, but an empty field means "not set" (nil).
@MainActor
struct OptionalNumberEntry: View {
    let label: String
    let key: String
    @Binding var value: Double?
    @Binding var invalidFields: Set<String>
    var maxDecimals: Int = 2
    @State private var text = ""
    @Environment(\.l10n) private var l

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            TextField(label, text: $text, prompt: Text(l.t("entry.notSet")))
                .monospacedDigit()
                .onAppear { text = value.map { l.plain($0) } ?? "" }
                .onChange(of: text) { _, new in
                    if new.trimmingCharacters(in: .whitespaces).isEmpty { value = nil; invalidFields.remove(key) }
                    else if let result = parseDecimal(new, maxDecimals: maxDecimals) { value = result; invalidFields.remove(key) }
                    else { invalidFields.insert(key) }
                }
                .onChange(of: value) { _, new in
                    let current = text.trimmingCharacters(in: .whitespaces).isEmpty ? nil : parseDecimal(text, maxDecimals: maxDecimals)
                    if current != new { text = new.map { l.plain($0) } ?? "" }
                }
                .onDisappear { invalidFields.remove(key) }
            if invalidFields.contains(key) {
                Text(l.t("entry.invalidNumber")).font(.caption2).foregroundStyle(Theme.alert)
            }
        }
    }
}

/// An optional whole number chosen from a range ("Not set" plus the values).
@MainActor
struct OptionalIntPicker: View {
    let label: String
    let range: ClosedRange<Int>
    @Binding var value: Int?
    @Environment(\.l10n) private var l
    var body: some View {
        Picker(label, selection: $value) {
            Text(l.t("entry.notSet")).tag(Int?.none)
            ForEach(Array(range), id: \.self) { n in Text(l.int(n)).tag(Int?.some(n)) }
        }
    }
}
