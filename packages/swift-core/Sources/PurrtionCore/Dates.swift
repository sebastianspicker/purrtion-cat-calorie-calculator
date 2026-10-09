import Foundation

/// Calendar dates are strict `YYYY-MM-DD` strings, parsed as UTC midnight (ENGINE.md §2). Day math is exact integer arithmetic.
public enum Dates {
    private static func civil(_ value: String) -> (year: Int, month: Int, day: Int)? {
        let b = Array(value.utf8)
        guard b.count == 10, b[4] == 45, b[7] == 45 else { return nil }
        func number(_ range: Range<Int>) -> Int? {
            var n = 0
            for i in range { guard (48...57).contains(b[i]) else { return nil }; n = n * 10 + Int(b[i] - 48) }
            return n
        }
        guard let y = number(0..<4), let m = number(5..<7), let d = number(8..<10), y >= 100, (1...12).contains(m), d >= 1 else { return nil } // years below 100 are rejected like the TypeScript engine
        let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
        let length = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
        return d <= length ? (y, m, d) : nil
    }
    public static func isISODate(_ value: String) -> Bool { civil(value) != nil }
    /// Days since 1970-01-01 (proleptic Gregorian), or nil for an invalid date.
    public static func dayNumber(_ value: String) -> Int? {
        guard let (year, month, day) = civil(value) else { return nil }
        let y = month <= 2 ? year - 1 : year, era = y / 400, yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        return era * 146_097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719_468
    }
    /// days(a, b) = (b − a) / 86 400 000 ms
    public static func daysBetween(_ from: String, _ to: String) throws -> Double {
        guard let a = dayNumber(from), let b = dayNumber(to) else {
            throw PlanError("Expected a valid YYYY-MM-DD date, got \"\(dayNumber(from) == nil ? from : to)\"")
        }
        return Double(b - a)
    }
    /// Today's date in the user's local time zone; the UI passes this as `asOf`.
    public static func todayLocal(_ now: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }
}
