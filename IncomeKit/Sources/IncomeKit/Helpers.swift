import Foundation

public enum TimeRange {
    /// Duration in minutes; an end before the start rolls to the next day (overnight shifts).
    public static func minutes(start: Date, end: Date, calendar: Calendar) -> Int {
        let s = calendar.dateComponents([.hour, .minute], from: start)
        let e = calendar.dateComponents([.hour, .minute], from: end)
        let sm = (s.hour ?? 0) * 60 + (s.minute ?? 0)
        var em = (e.hour ?? 0) * 60 + (e.minute ?? 0)
        if em <= sm { em += 24 * 60 }
        return em - sm
    }

    /// Optional "hours × rate" helper. Rate in cents per hour; rounds to the nearest cent.
    public static func amount(minutes: Int, ratePerHour: Cents) -> Cents {
        Int((Double(minutes) * Double(ratePerHour) / 60).rounded())
    }
}

public enum RecurrenceEngine {
    /// Dates for a repeating entry, starting at `first`, `count` occurrences (first included).
    /// Monthly keeps the day-of-month, clamping to the month's last day (31 Jan → 28/29 Feb).
    public static func dates(first: Date, rule: Recurrence, count: Int, calendar: Calendar) -> [Date] {
        guard rule != .none, count > 1 else { return [first] }
        return (0..<count).map { i in
            switch rule {
            case .none: first
            case .weekly: calendar.date(byAdding: .day, value: 7 * i, to: first)!
            case .fortnightly: calendar.date(byAdding: .day, value: 14 * i, to: first)!
            case .monthly: calendar.date(byAdding: .month, value: i, to: first)!
            }
        }
    }
}

public enum TaxEstimator {
    /// Simple flat estimate: amount set aside = income × rate%. Rate is a percentage (e.g. 19.0).
    public static func setAside(income: Cents, ratePercent: Double) -> Cents {
        guard ratePercent > 0 else { return 0 }
        return Int((Double(income) * ratePercent / 100).rounded())
    }
}

public enum CSVExporter {
    public struct Row: Sendable {
        public let date: Date, start: Date?, end: Date?
        public let stream: String, client: String, amount: Cents, note: String
        public init(date: Date, start: Date?, end: Date?, stream: String, client: String, amount: Cents, note: String) {
            self.date = date; self.start = start; self.end = end
            self.stream = stream; self.client = client; self.amount = amount; self.note = note
        }
    }

    static func escape(_ s: String) -> String {
        guard s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    public static func csv(_ rows: [Row], timeZone: TimeZone = .current) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = timeZone
        let tf = DateFormatter(); tf.locale = df.locale; tf.timeZone = timeZone
        df.dateFormat = "yyyy-MM-dd"; tf.dateFormat = "HH:mm"
        var out = "Date,Start,End,Stream,Client,Amount,Note\r\n"
        for r in rows.sorted(by: { $0.date < $1.date }) {
            let a = abs(r.amount)
            let amt = (r.amount < 0 ? "-" : "") + "\(a / 100)." + String(format: "%02d", a % 100)
            out += [df.string(from: r.date), r.start.map(tf.string) ?? "", r.end.map(tf.string) ?? "",
                    escape(r.stream), escape(r.client), amt, escape(r.note)].joined(separator: ",") + "\r\n"
        }
        return out
    }
}
