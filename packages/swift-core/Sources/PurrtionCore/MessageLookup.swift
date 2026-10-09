import Foundation

extension Messages {
    /// User-facing text for a namespaced code such as `warning.over-budget` or `refer.bcs-low`.
    /// `locale` is a language code or identifier ("en", "de", "de-DE"); unknown locales and keys fall back to English, then to the key.
    public static func message(_ key: String, locale: String) -> String {
        let language = String(locale.lowercased().prefix(2))
        let table = language == "de" ? de : en
        return table[key] ?? en[key] ?? key
    }
}
