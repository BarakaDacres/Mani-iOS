import Foundation
import Testing
@testable import IncomeKit

let syd = TimeZone(identifier: "Australia/Sydney")!
func cal(_ y: YearType = .australianFY, first: Int = 2) -> ReportingCalendar {
    ReportingCalendar(yearType: y, firstWeekday: first, timeZone: syd)
}
func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    cal().calendar.date(from: DateComponents(year: y, month: m, day: day, hour: h, minute: min))!
}

@Suite struct MoneyTests {
    @Test func parse() {
        #expect(Money.cents(from: "1,234.5") == 123450)
        #expect(Money.cents(from: "$80") == 8000)
        #expect(Money.cents(from: ".75") == 75)
        #expect(Money.cents(from: "189.333") == 18933)
        #expect(Money.cents(from: "") == nil)
        #expect(Money.cents(from: "1.2.3") == nil)
    }
    @Test func format() {
        #expect(Money.format(737980) == "$7,379.80")
        #expect(Money.format(3633721) == "$36,337.21")
        #expect(Money.format(-505) == "-$5.05")
        #expect(Money.formatWhole(737980) == "$7,380")
        #expect(Money.formatCompact(69800) == "$698")
        #expect(Money.formatCompact(103017) == "$1,030")
        #expect(Money.formatCompact(1240000) == "$12.4k")
        #expect(Money.formatCompact(1000000) == "$10k")
    }
}

@Suite struct ReportingTests {
    @Test func fyLabelAndInterval() {
        let c = cal()
        #expect(c.yearLabel(containing: d(2026, 10, 15)) == "FY 26-27")
        #expect(c.yearLabel(containing: d(2026, 6, 30)) == "FY 25-26")
        let i = c.yearInterval(containing: d(2027, 3, 1))
        #expect(i.start == d(2026, 7, 1)); #expect(i.end == d(2027, 7, 1))
        #expect(cal(.calendar).yearLabel(containing: d(2026, 10, 15)) == "2026")
        #expect(cal(.calendar).yearInterval(containing: d(2026, 10, 15)).start == d(2026, 1, 1))
    }
    @Test func status() {
        let c = cal(), now = d(2026, 10, 15, 14)
        #expect(c.status(of: d(2026, 10, 15, 23, 59), now: now) == .today)
        #expect(c.status(of: d(2026, 10, 16), now: now) == .upcoming)
        #expect(c.status(of: d(2026, 10, 14, 23), now: now) == .past)
    }
    @Test func gridMondayFirst() {
        // 1 Oct 2026 is a Thursday → 3 leading blanks Monday-first, 4 Sunday-first.
        #expect(cal().monthGrid(for: d(2026, 10, 1)).prefix { $0 == nil }.count == 3)
        #expect(cal(first: 1).monthGrid(for: d(2026, 10, 1)).prefix { $0 == nil }.count == 4)
        #expect(cal().monthGrid(for: d(2026, 10, 1)).compactMap { $0 }.count == 31)
        #expect(cal().orderedWeekdaySymbols.first == "M")
        #expect(cal(first: 7).orderedWeekdaySymbols == ["S","S","M","T","W","T","F"])
    }
}

@Suite struct AggregationTests {
    let a = UUID(), b = UUID()
    var rs: [IncomeRecord] {[
        .init(streamID: a, amount: 80000, date: d(2026, 10, 17)),   // upcoming
        .init(streamID: b, amount: 37548, date: d(2026, 10, 16)),
        .init(streamID: b, amount: 18933, date: d(2026, 10, 15)),
        .init(streamID: b, amount: 33245, date: d(2026, 10, 14, 22)),
        .init(streamID: a, amount: 10000, date: d(2026, 9, 30)),
        .init(streamID: a, amount: 5000, date: d(2026, 6, 30)),     // previous FY
    ]}
    @Test func totalsIncludeUpcoming() {
        let g = Aggregator(cal())
        #expect(g.total(rs, in: cal().monthInterval(containing: d(2026, 10, 1))) == 169726)
        #expect(g.total(rs, in: cal().yearInterval(containing: d(2026, 10, 1))) == 179726)
    }
    @Test func sharesSumTo100() {
        let x = UUID(), y = UUID(), z = UUID()
        let s = Aggregator(cal()).shares([
            .init(streamID: x, amount: 1, date: .now), .init(streamID: y, amount: 1, date: .now),
            .init(streamID: z, amount: 1, date: .now)])
        #expect(s.map(\.percent).reduce(0, +) == 100)
        let t = Aggregator(cal()).shares(rs)
        #expect(t.first?.streamID == a || t.first?.streamID == b)
        #expect(t.map(\.percent).reduce(0, +) == 100)
        #expect(Aggregator(cal()).shares([]).isEmpty)
    }
    @Test func series() {
        let g = Aggregator(cal())
        let daily = g.series(rs, granularity: .daily, anchor: d(2026, 10, 5))
        #expect(daily.count == 31); #expect(daily[16].total == 80000)
        let monthly = g.series(rs, granularity: .monthly, anchor: d(2026, 10, 5))
        #expect(monthly.count == 12); #expect(monthly.first?.label == "Jul")
        #expect(monthly[3].total == 169726); #expect(monthly[2].total == 10000)
        let yearly = g.series(rs, granularity: .yearly, anchor: d(2026, 10, 5))
        #expect(yearly.map(\.label) == ["FY 25-26", "FY 26-27"])
        let weekly = g.series(rs, granularity: .weekly, anchor: d(2026, 10, 5))
        #expect(weekly.first?.start == d(2026, 9, 28)) // Monday
        #expect(weekly.reduce(0) { $0 + $1.total } == 169726 + 10000)
    }
    @Test func grouping() {
        let gs = Aggregator(cal()).groupedByDay(rs)
        #expect(gs.first?.day == d(2026, 10, 17))
        #expect(gs.count == 6)
    }
}

@Suite struct HelperTests {
    @Test func overnight() {
        let c = cal().calendar
        #expect(TimeRange.minutes(start: d(2026,10,14,22), end: d(2026,10,14,10), calendar: c) == 720)
        #expect(TimeRange.minutes(start: d(2026,10,14,9), end: d(2026,10,14,17), calendar: c) == 480)
        #expect(TimeRange.amount(minutes: 450, ratePerHour: 4250) == 31875)
    }
    @Test func recurrence() {
        let c = cal().calendar
        #expect(RecurrenceEngine.dates(first: d(2026,10,1), rule: .fortnightly, count: 3, calendar: c)
                == [d(2026,10,1), d(2026,10,15), d(2026,10,29)])
        #expect(RecurrenceEngine.dates(first: d(2027,1,31), rule: .monthly, count: 2, calendar: c)[1] == d(2027,2,28))
        #expect(RecurrenceEngine.dates(first: d(2026,10,1), rule: .none, count: 5, calendar: c).count == 1)
    }
    @Test func tax() {
        #expect(TaxEstimator.setAside(income: 737980, ratePercent: 19) == 140216)
        #expect(TaxEstimator.setAside(income: 1000, ratePercent: 0) == 0)
    }
    @Test func csv() {
        let s = CSVExporter.csv([.init(date: d(2026,10,14), start: d(2026,10,14,22), end: d(2026,10,15,10),
                                       stream: "Employment", client: "Tom, Jr", amount: 33245, note: "said \"hi\"")],
                                timeZone: syd)
        #expect(s == "Date,Start,End,Stream,Client,Amount,Note\r\n2026-10-14,22:00,10:00,Employment,\"Tom, Jr\",332.45,\"said \"\"hi\"\"\"\r\n")
    }
}
