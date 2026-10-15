import Foundation

public struct StreamShare: Sendable, Equatable {
    public let streamID: UUID?
    public let total: Cents
    public let percent: Int
}

public struct ChartPoint: Sendable, Equatable, Identifiable {
    public var id: Date { start }
    public let start: Date
    public let label: String
    public let total: Cents
}

/// All totals include upcoming (future-dated) entries, by product decision.
public struct Aggregator: Sendable {
    public let cal: ReportingCalendar
    public init(_ cal: ReportingCalendar) { self.cal = cal }

    public func total(_ rs: [IncomeRecord], in i: DateInterval) -> Cents {
        rs.lazy.filter { i.start <= $0.date && $0.date < i.end }.reduce(0) { $0 + $1.amount }
    }

    public func records(_ rs: [IncomeRecord], in i: DateInterval) -> [IncomeRecord] {
        rs.filter { i.start <= $0.date && $0.date < i.end }
    }

    public func dailyTotals(_ rs: [IncomeRecord]) -> [Date: Cents] {
        var d: [Date: Cents] = [:]
        for r in rs { d[cal.startOfDay(r.date), default: 0] += r.amount }
        return d
    }

    /// Shares by stream, sorted desc; percents use largest-remainder so they sum to 100.
    public func shares(_ rs: [IncomeRecord]) -> [StreamShare] {
        var t: [UUID?: Cents] = [:]
        for r in rs where r.amount > 0 { t[r.streamID, default: 0] += r.amount }
        let sum = t.values.reduce(0, +)
        guard sum > 0 else { return [] }
        let sorted = t.sorted { $0.value != $1.value ? $0.value > $1.value : ($0.key?.uuidString ?? "") < ($1.key?.uuidString ?? "") }
        var floors = sorted.map { $0.value * 100 / sum }
        var left = 100 - floors.reduce(0, +)
        let order = sorted.indices.sorted { (sorted[$0].value * 100 % sum) > (sorted[$1].value * 100 % sum) }
        for i in order where left > 0 { floors[i] += 1; left -= 1 }
        return sorted.enumerated().map { StreamShare(streamID: $1.key, total: $1.value, percent: floors[$0]) }
    }

    /// Chart buckets around `anchor`:
    /// daily → each day of anchor's month; weekly → weeks overlapping the month;
    /// monthly → 12 months of the reporting year; yearly → every reporting year with data (min 1).
    public func series(_ rs: [IncomeRecord], granularity g: Granularity, anchor: Date) -> [ChartPoint] {
        let c = cal.calendar
        var buckets: [DateInterval] = []
        var labels: [String] = []
        switch g {
        case .daily:
            let m = cal.monthInterval(containing: anchor)
            var d = m.start
            while d < m.end {
                let n = c.date(byAdding: .day, value: 1, to: d)!
                buckets.append(DateInterval(start: d, end: n)); labels.append(String(c.component(.day, from: d)))
                d = n
            }
        case .weekly:
            let m = cal.monthInterval(containing: anchor)
            var w = cal.weekInterval(containing: m.start).start
            while w < m.end {
                let n = c.date(byAdding: .day, value: 7, to: w)!
                buckets.append(DateInterval(start: w, end: n))
                labels.append("\(c.component(.day, from: w))/\(c.component(.month, from: w))")
                w = n
            }
        case .monthly:
            let y = cal.yearInterval(containing: anchor)
            let names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
            var d = y.start
            while d < y.end {
                let n = c.date(byAdding: .month, value: 1, to: d)!
                buckets.append(DateInterval(start: d, end: n)); labels.append(names[c.component(.month, from: d) - 1])
                d = n
            }
        case .yearly:
            let years = rs.map { cal.reportingStartYear(for: $0.date) } + [cal.reportingStartYear(for: anchor)]
            for y in (years.min()!)...(years.max()!) {
                buckets.append(cal.yearInterval(startYear: y)); labels.append(cal.yearLabel(startYear: y))
            }
        }
        return zip(buckets, labels).map { ChartPoint(start: $0.start, label: $1, total: total(rs, in: $0)) }
    }

    /// Entries grouped by day, newest first (upcoming at the top), as on History.
    public func groupedByDay(_ rs: [IncomeRecord]) -> [(day: Date, total: Cents, records: [IncomeRecord])] {
        Dictionary(grouping: rs) { cal.startOfDay($0.date) }
            .map { day, items in
                (day, items.reduce(0) { $0 + $1.amount },
                 items.sorted { ($0.start ?? $0.date) > ($1.start ?? $1.date) })
            }
            .sorted { $0.day > $1.day }
    }
}
