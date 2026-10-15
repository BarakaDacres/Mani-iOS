import Foundation

/// Money is stored as integer cents everywhere so totals never drift.
public typealias Cents = Int

public enum Money {
    /// Parses user input like "1,234.5", "$80", ".75" into cents. Returns nil for invalid input.
    public static func cents(from text: String) -> Cents? {
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let whole = parts[0].isEmpty ? 0 : Int(parts[0])
        guard let whole else { return nil }
        var frac = 0
        if parts.count == 2 {
            let f = String(parts[1].prefix(2))
            if !f.isEmpty {
                guard let v = Int(f) else { return nil }
                frac = f.count == 1 ? v * 10 : v
            }
        }
        return whole * 100 + frac
    }

    private static func grouped(_ n: Int) -> String {
        let s = String(n)
        var out = ""
        for (i, ch) in s.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return String(out.reversed())
    }

    /// "$7,379.80" (en-AU style, deterministic on every platform).
    public static func format(_ cents: Cents, symbol: String = "$") -> String {
        let neg = cents < 0
        let a = abs(cents)
        let body = "\(symbol)\(grouped(a / 100)).\(String(format: "%02d", a % 100))"
        return neg ? "-\(body)" : body
    }

    /// Whole dollars, rounded: "$7,380".
    public static func formatWhole(_ cents: Cents, symbol: String = "$") -> String {
        let dollars = Int((Double(cents) / 100).rounded())
        return (dollars < 0 ? "-" : "") + symbol + grouped(abs(dollars))
    }

    /// Compact for calendar cells: "$698", "$1,030", "$12.4k", "$1.2m".
    public static func formatCompact(_ cents: Cents, symbol: String = "$") -> String {
        let d = Double(cents) / 100
        switch abs(d) {
        case 1_000_000...: return symbol + trim(d / 1_000_000) + "m"
        case 10_000...: return symbol + trim(d / 1_000) + "k"
        default: return formatWhole(cents, symbol: symbol)
        }
    }

    private static func trim(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}
