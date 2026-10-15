import SwiftUI
import SwiftData
import IncomeKit

enum PeriodScope: String, CaseIterable { case month = "Month", year = "Year" }

struct HomeView: View {
    var onAdd: () -> Void
    @Query(sort: \IncomeEntry.date, order: .reverse) private var entries: [IncomeEntry]
    @AppStorage(Pref.yearType) private var yearTypeRaw = YearType.australianFY.rawValue
    @AppStorage(Pref.firstWeekday) private var firstWeekday = 2
    @State private var scope: PeriodScope = .month
    @State private var shownMonth = Date.now
    @State private var selectedDay: DayID?

    private var rc: ReportingCalendar {
        ReportingCalendar(yearType: YearType(rawValue: yearTypeRaw) ?? .australianFY, firstWeekday: firstWeekday)
    }
    private var records: [IncomeRecord] { entries.map(\.record) }

    var body: some View {
        let agg = Aggregator(rc), now = Date.now
        let monthTotal = agg.total(records, in: rc.monthInterval(containing: now))
        let yearTotal = agg.total(records, in: rc.yearInterval(containing: now))
        let todays = entries.filter { rc.status(of: $0.date, now: now) == .today }

        ScrollView {
            VStack(spacing: Theme.gap) {
                Card {
                    HStack(alignment: .top) {
                        Text(scope == .month ? "This \(now.formatted(.dateTime.month(.abbreviated)))" : rc.yearLabel(containing: now))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("Income").font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.elevated, in: .capsule)
                    }
                    RollingAmount(cents: scope == .month ? monthTotal : yearTotal)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Income").font(.subheadline).foregroundStyle(Theme.textSecondary)
                            RollingAmount(cents: yearTotal, font: .headline, color: Theme.accentTint)
                        }
                        Spacer()
                        GlassSegmented(options: PeriodScope.allCases, selection: $scope) { $0.rawValue }
                            .frame(width: 170)
                    }
                }
                .appearLift(0)

                PrimaryGlassButton(title: "Add Income", systemImage: "plus", action: onAdd)
                    .appearLift(1)

                Card {
                    Text("Today's Income").foregroundStyle(Theme.textSecondary)
                    RollingAmount(cents: todays.reduce(0) { $0 + $1.amountCents })
                    if todays.isEmpty {
                        Text("Nothing logged for today yet.").font(.subheadline).foregroundStyle(Theme.textTertiary)
                    }
                    ForEach(todays) { EntryRow(entry: $0, showsDelete: false) }
                }
                .appearLift(2)

                CalendarCard(rc: rc, month: $shownMonth, totals: agg.dailyTotals(records)) { day in
                    selectedDay = DayID(date: day)
                }
                .appearLift(3)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(ManiBackground())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDay) { DaySheet(day: $0.date) }
    }
}

struct DayID: Identifiable { let date: Date; var id: Date { date } }

/// Month calendar with daily totals in filled circles; today gets a ring.
struct CalendarCard: View {
    let rc: ReportingCalendar
    @Binding var month: Date
    let totals: [Date: Cents]
    var onSelect: (Date) -> Void
    @State private var direction: Edge = .trailing

    var body: some View {
        let grid = rc.monthGrid(for: month)
        let monthTotal = rc.monthGrid(for: month).compactMap { $0 }.reduce(0) { $0 + (totals[$1] ?? 0) }
        Card(padding: 18) {
            HStack {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                VStack(spacing: 2) {
                    Text(month.formatted(.dateTime.month(.abbreviated).year())).font(.headline)
                    RollingAmount(cents: monthTotal, font: .subheadline.weight(.semibold), color: Theme.accentTint)
                }
                Spacer()
                Button { step(1) } label: { Image(systemName: "chevron.right") }
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.bottom, 6)

            let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(Array(rc.orderedWeekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.caption).foregroundStyle(Theme.textSecondary)
                }
                ForEach(Array(grid.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 46) }
                }
            }
            .id(month)
            .transition(.push(from: direction))
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width < -40 { step(1) } else if v.translation.width > 40 { step(-1) }
        })
    }

    private func dayCell(_ day: Date) -> some View {
        let t = totals[day] ?? 0
        let isToday = rc.status(of: day) == .today
        return Button { onSelect(day) } label: {
            VStack(spacing: 1) {
                Text("\(rc.calendar.component(.day, from: day))").font(.subheadline.weight(.medium))
                if t > 0 { Text(Money.formatCompact(t)).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7) }
            }
            .foregroundStyle(t > 0 ? Theme.textPrimary : Theme.textSecondary)
            .frame(width: 46, height: 46)
            .background(t > 0 ? Theme.accentSubtle : .clear, in: .circle)
            .overlay(Circle().strokeBorder(isToday ? Theme.accentTint : .clear, lineWidth: 1.5))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("\(day.formatted(date: .long, time: .omitted)), \(Money.format(t))")
    }

    private func step(_ n: Int) {
        direction = n > 0 ? .trailing : .leading
        withAnimation(Motion.spring) { month = rc.calendar.date(byAdding: .month, value: n, to: month)! }
    }
}

/// A single entry row: stream tile, name, subtitle, amount, optional trash.
struct EntryRow: View {
    let entry: IncomeEntry
    var showsDelete = true
    var onDelete: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 14) {
            StreamIconTile(icon: entry.stream?.iconKey ?? .wallet, color: entry.stream?.colorKey ?? .sand)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.stream?.name ?? "Income").font(.body.weight(.medium)).foregroundStyle(Theme.textPrimary)
                if !entry.subtitle.isEmpty {
                    Text(entry.subtitle).font(.subheadline).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            Spacer()
            Text(Money.format(entry.amountCents)).font(.body.weight(.semibold)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            if showsDelete, let onDelete {
                Button(action: onDelete) { Image(systemName: "trash").foregroundStyle(Theme.textSecondary) }
                    .buttonStyle(.plain).accessibilityLabel("Delete")
            }
        }
        .padding(.vertical, 6)
    }
}

/// Entries for one calendar day, with a shortcut to add income on that date.
struct DaySheet: View {
    let day: Date
    @Query private var entries: [IncomeEntry]
    @Environment(\.modelContext) private var context
    @State private var adding = false

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _entries = Query(filter: #Predicate<IncomeEntry> { $0.date >= start && $0.date < end }, sort: \.amountCents, order: .reverse)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(entries) { e in
                        EntryRow(entry: e, showsDelete: false)
                    }
                    .onDelete { idx in idx.map { entries[$0] }.forEach { DataService(context: context).delete($0) } }
                } footer: {
                    Text("Total \(Money.format(entries.reduce(0) { $0 + $1.amountCents }))")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ManiBackground())
            .overlay { if entries.isEmpty { ContentUnavailableView("No income", systemImage: "calendar") } }
            .navigationTitle(day.formatted(.dateTime.day().month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { AddIncomeSheet(initialDate: day) }
        }
        .presentationDetents([.medium, .large])
    }
}
