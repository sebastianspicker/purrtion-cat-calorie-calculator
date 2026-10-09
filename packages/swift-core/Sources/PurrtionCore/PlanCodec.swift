import Foundation

public enum PlanCodec {
    public static let maximumImportBytes = 1_048_576
    /// Decodes a v1 or v2 document (v1 is migrated, ENGINE.md §9) and validates it.
    public static func decode(_ data: Data) throws -> Plan {
        guard data.count <= maximumImportBytes else { throw PlanError("file: maximum size is 1 MiB") }
        let plan: Plan
        do { plan = try JSONDecoder().decode(Plan.self, from: data) }
        catch let error as PlanError { throw error }
        catch let error as DecodingError {
            let context: DecodingError.Context
            switch error {
            case .typeMismatch(_, let c), .valueNotFound(_, let c), .keyNotFound(_, let c), .dataCorrupted(let c): context = c
            @unknown default: throw PlanError("file: invalid plan document")
            }
            let path = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
            throw PlanError("\(path.isEmpty ? "file" : String(path.drop { $0 == "." })): invalid or missing value")
        }
        try PlanValidator.validate(plan)
        return plan
    }
    public static func encode(_ plan: Plan) throws -> Data {
        try PlanValidator.validate(plan)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(plan); data.append(0x0A)
        return data
    }
    public static func sample() throws -> Plan {
        #if os(macOS)
        let packagedURL = Bundle.main.resourceURL?.appendingPathComponent("Purrtion_PurrtionCore.bundle")
        let resourceBundle = packagedURL.flatMap { Bundle(url: $0) } ?? Bundle.module
        #else
        let resourceBundle = Bundle.module
        #endif
        guard let url = resourceBundle.url(forResource: "default-plan", withExtension: "json") else {
            throw PlanError("The bundled sample plan is missing. Run script/sync_shared.sh and rebuild.")
        }
        return try decode(Data(contentsOf: url))
    }
    /// JavaScript `String(number)` for the values that appear in the CSV: whole numbers without a trailing ".0".
    private static func number(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15 ? String(Int64(value)) : String(value)
    }
    private static func fixed(_ value: Double, _ digits: Int) -> String {
        String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    /// Same columns as the TypeScript `planToCSV`.
    public static func csv(_ plan: Plan, asOf: String) throws -> String {
        let result = try CalorieCalculator.calculate(plan, asOf: asOf)
        var rows = [["Cat", "Weight (kg)", "Goal", "Target (kcal/day)", "Fixed meals (g/day)", "Fixed meals (kcal/day)", "Extras (kcal/day)",
                     "Balance food", "Balance food calculated (g/day)", "Balance food rounded (g/day)", "Calories after rounding",
                     "Estimate status", "Estimate start (kcal/day)", "Estimate range (kcal/day)", "Warnings"]]
        for cat in plan.cats {
            let r = result.cats.first { $0.id == cat.id }!, e = r.estimate
            rows.append([cat.name, number(cat.weightKg), cat.goal.rawValue, number(cat.targetKcal), number(r.fixedGrams), number(r.fixedKcal),
                number(cat.extraKcal), plan.foods.first { $0.id == cat.balanceFoodId }!.name, fixed(r.balanceGramsExact, 4),
                String(r.balanceGramsRounded), fixed(r.roundedDailyKcal, 2), e.status.rawValue,
                e.startKcal.map { fixed($0.rounded(.toNearestOrAwayFromZero), 0) } ?? "",
                e.lowKcal.flatMap { low in e.highKcal.map { "\(fixed(low.rounded(.toNearestOrAwayFromZero), 0))–\(fixed($0.rounded(.toNearestOrAwayFromZero), 0))" } } ?? "",
                r.warnings.map(\.rawValue).joined(separator: "; ")])
        }
        return rows.map { $0.map(csvCell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
    static func csvCell(_ value: String) -> String {
        var text = value
        if let first = text.unicodeScalars.first, "=+@-\t\r\n".unicodeScalars.contains(first) { text = "'" + text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
