import Foundation

/// Calendar helpers bound to one calendar/time zone and a user-chosen first weekday.
public struct ReportingCalendar: Sendable {
    public var calendar: Calendar
    public var yearType: YearType

    /// firstWeekday: 1 = Sunday … 2 = Monday (default) … 7 = Saturday.
    public init(yearType: YearType = .australianFY, firstWeekday: Int = 2,
                timeZone: TimeZone = .current) {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = Locale(identifier: "en_AU")
        c.firstWeekday = min(max(firstWeekday, 1), 7)
        c.minimumDaysInFirstWeek = 1
        self.calendar = c
        self.yearType = yearType
    }

    public func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }

    public func status(of date: Date, now: Date = .now) -> EntryStatus {
        let a = startOfDay(date), b = startOfDay(now)
        if a == b { return .today }
        return a > b ? .upcoming : .past
    }

    public func monthInterval(containing d: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: d)!
    }

    public func weekInterval(containing d: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: d)!
    }

    /// The first year of the reporting year containing `d` (FY 26-27 → 2026).
    public func reportingStartYear(for d: Date) -> Int {
        let y = calendar.component(.year, from: d)
        guard yearType == .australianFY else { return y }
        return calendar.component(.month, from: d) >= 7 ? y : y - 1
    }

    public func yearInterval(startYear y: Int) -> DateInterval {
        let startMonth = yearType == .australianFY ? 7 : 1
        let s = calendar.date(from: DateComponents(year: y, month: startMonth, day: 1))!
        let e = calendar.date(byAdding: .year, value: 1, to: s)!
        return DateInterval(start: s, end: e)
    }

    public func yearInterval(containing d: Date) -> DateInterval {
        yearInterval(startYear: reportingStartYear(for: d))
    }

    /// "FY 26-27" or "2026".
    public func yearLabel(startYear y: Int) -> String {
        guard yearType == .australianFY else { return String(y) }
        return String(format: "FY %02d-%02d", y % 100, (y + 1) % 100)
    }

    public func yearLabel(containing d: Date) -> String { yearLabel(startYear: reportingStartYear(for: d)) }

    /// Weekday symbols ordered from firstWeekday, e.g. ["M","T","W","T","F","S","S"].
    public var orderedWeekdaySymbols: [String] {
        let s = ["S", "M", "T", "W", "T", "F", "S"]
        let f = calendar.firstWeekday - 1
        return Array(s[f...] + s[..<f])
    }

    /// Calendar grid for a month: leading nils for padding, then each day's start.
    public func monthGrid(for d: Date) -> [Date?] {
        let m = monthInterval(containing: d)
        let wd = calendar.component(.weekday, from: m.start)
        let lead = (wd - calendar.firstWeekday + 7) % 7
        let days = calendar.range(of: .day, in: .month, for: m.start)!.count
        var out: [Date?] = Array(repeating: nil, count: lead)
        for i in 0..<days { out.append(calendar.date(byAdding: .day, value: i, to: m.start)!) }
        return out
    }
}
