import SwiftUI
import PurrtionCore

/// The language setting in the Settings scene, stored under `L10n.storageKey`.
enum AppLanguage: String, CaseIterable, Sendable { case system, en, de }

/// UI strings (en/de) and locale-aware formatting. Engine texts always come from `Messages.message`.
struct L10n: Sendable, Equatable {
    static let storageKey = "purrtion.language"
    /// "en" or "de".
    let language: String
    let locale: Locale

    static func resolve(_ setting: String) -> L10n {
        switch AppLanguage(rawValue: setting) ?? .system {
        case .en: return L10n(language: "en", locale: Locale(identifier: "en_GB"))
        case .de: return L10n(language: "de", locale: Locale(identifier: "de_DE"))
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return L10n(language: preferred.lowercased().hasPrefix("de") ? "de" : "en", locale: Locale.autoupdatingCurrent)
        }
    }

    // MARK: Strings
    /// App-owned UI text.
    func t(_ key: String) -> String {
        let table = language == "de" ? L10nStrings.de : L10nStrings.en
        return table[key] ?? L10nStrings.en[key] ?? key
    }
    /// App-owned UI text with `{name}` placeholders.
    func t(_ key: String, _ arguments: [String: String]) -> String {
        var text = t(key)
        for (name, value) in arguments { text = text.replacingOccurrences(of: "{\(name)}", with: value) }
        return text
    }
    /// Engine text for a namespaced code (warning.*, refer.*, note.*, …).
    func msg(_ key: String) -> String { Messages.message(key, locale: language) }

    // MARK: Numbers
    func num(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
    }
    func fixed(_ value: Double, _ digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(locale))
    }
    func int(_ value: Double) -> String {
        value.rounded(.toNearestOrAwayFromZero).formatted(.number.precision(.fractionLength(0)).locale(locale))
    }
    func int(_ value: Int) -> String { value.formatted(.number.locale(locale)) }
    /// Text-field form: no grouping separators, so NumberEntry can parse it back.
    func plain(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...4)).locale(locale))
    }
    func percent(_ value: Double, digits: Int = 1) -> String { "\(num(value, digits: digits)) %" }
    func signedPercent(_ value: Double, digits: Int = 1) -> String {
        "\(value > 0 ? "+" : value < 0 ? "−" : "")\(num(abs(value), digits: digits)) %"
    }
    func kcalPerDay(_ value: Double) -> String { "\(int(value)) \(t("unit.kcalPerDay"))" }
    func grams(_ value: Double, digits: Int = 1) -> String { "\(num(value, digits: digits)) g" }
    func kg(_ value: Double, digits: Int = 2) -> String { "\(num(value, digits: digits)) kg" }

    // MARK: Dates
    /// A calendar date (YYYY-MM-DD) as a localised medium date.
    func date(_ iso: String) -> String {
        guard let date = ISODate.date(iso) else { return iso }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    // MARK: Enum titles
    func goal(_ value: Goal) -> String { t("goal.\(value.rawValue)") }
    func targetSource(_ value: TargetSource) -> String { t("targetSource.\(value.rawValue)") }
    func completeness(_ value: Completeness) -> String { t("completeness.\(value.rawValue)") }
    func foodType(_ value: FoodType) -> String { t("foodType.\(value.rawValue)") }
    func energySource(_ value: EnergySource) -> String { t("energySource.\(value.rawValue)") }
    func lifeStageClaim(_ value: LifeStageClaim) -> String { t("lifeStageClaim.\(value.rawValue)") }
    func analysisKind(_ value: AnalysisKind) -> String { t("analysisKind.\(value.rawValue)") }
    func sex(_ value: Sex) -> String { t("sex.\(value.rawValue)") }
    func neutered(_ value: Neutered) -> String { t("neutered.\(value.rawValue)") }
    func lifestyle(_ value: Lifestyle) -> String { t("lifestyle.\(value.rawValue)") }
    func lifestyleDescription(_ value: Lifestyle) -> String { t("lifestyle.\(value.rawValue).description") }
    func mcs(_ value: MuscleCondition) -> String { t("mcs.\(value.rawValue)") }
    func reproduction(_ value: ReproductionStatus) -> String { t("reproduction.\(value.rawValue)") }
    func bcsDescription(_ score: Int) -> String { t("bcs.\(score)") }
    func medical(_ flag: MedicalFlag) -> String { msg("medical.\(flag.rawValue)") }
    func status(_ value: EstimateStatus) -> String { msg("status.\(value.rawValue)") }
    func stage(_ value: Stage) -> String { msg("stage.\(value.rawValue)") }
    func lifeStage(_ value: LifeStageLabel) -> String { msg("lifeStage.\(value.rawValue)") }
}

private struct L10nKey: EnvironmentKey {
    static let defaultValue = L10n(language: "en", locale: Locale(identifier: "en_GB"))
}

extension EnvironmentValues {
    var l10n: L10n {
        get { self[L10nKey.self] }
        set { self[L10nKey.self] = newValue }
    }
}

/// Conversions between `YYYY-MM-DD` strings and local `Date`s for pickers and charts.
enum ISODate {
    /// Local noon of the calendar date, so DST changes never shift the day.
    static func date(_ iso: String) -> Date? {
        guard Dates.isISODate(iso) else { return nil }
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
    static func string(_ date: Date) -> String { Dates.todayLocal(date) }
    static func adding(days: Int, to iso: String) -> String? {
        guard let date = date(iso), let result = Calendar.current.date(byAdding: .day, value: days, to: date) else { return nil }
        return string(result)
    }
    static func today() -> Date { date(Dates.todayLocal()) ?? Date() }
}
