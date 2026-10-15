import SwiftUI
import SwiftData
import Charts
import IncomeKit

struct StatsView: View {
    @Query(sort: \IncomeEntry.date) private var entries: [IncomeEntry]
    @Query(sort: \IncomeStream.sortOrder) private var allStreams: [IncomeStream]
    @AppStorage(Pref.yearType) private var yearTypeRaw = YearType.australianFY.rawValue
    @AppStorage(Pref.firstWeekday) private var firstWeekday = 2
    @AppStorage(Pref.taxRate) private var taxRate = 0.0
    @State private var scope: PeriodScope = .month
    @State private var anchor = Date.now
    @State private var granularity: Granularity = .monthly
    @State private var filter: IncomeStream?
    @State private var donutSelection: Int?
    @State private var scrubbed: Date?
    @State private var drawn = false

    private var rc: ReportingCalendar {
        ReportingCalendar(yearType: YearType(rawValue: yearTypeRaw) ?? .australianFY, firstWeekday: firstWeekday)
    }

    var body: some View {
        let agg = Aggregator(rc)
        let all = entries.map(\.record)
        let period = scope == .month ? rc.monthInterval(containing: anchor) : rc.yearInterval(containing: anchor)
        let inPeriod = agg.records(all, in: period)
        let yearTotal = agg.total(all, in: rc.yearInterval(containing: anchor))
        let periodTotal = agg.total(all, in: period)

        ScrollView {
            VStack(spacing: Theme.gap) {
                heroCard(yearTotal: yearTotal, periodTotal: periodTotal, count: inPeriod.count).appearLift(0)
                if taxRate > 0 { taxCard(periodTotal: periodTotal).appearLift(1) }
                donutCard(agg.shares(inPeriod)).appearLift(2)
                trendCard(agg, all).appearLift(3)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(ManiBackground())
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { withAnimation(Motion.reveal) { drawn = true } }
    }

    private var periodName: String {
        scope == .month ? anchor.formatted(.dateTime.month(.abbreviated)) : rc.yearLabel(containing: anchor)
    }

    private func heroCard(yearTotal: Int, periodTotal: Int, count: Int) -> some View {
        Card {
            Text("Total Income \(rc.yearLabel(containing: anchor))").foregroundStyle(Theme.textSecondary)
            RollingAmount(cents: yearTotal)
            HStack(spacing: 4) {
                Text("\(periodName) selected ·").foregroundStyle(Theme.textSecondary)
                RollingAmount(cents: periodTotal, font: .subheadline.weight(.semibold), color: Theme.accentTint)
            }
            .font(.subheadline)
            HStack {
                HStack(spacing: 10) {
                    Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    Text("\(periodName) · \(count) entries").font(.subheadline).foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                    Button { step(1) } label: { Image(systemName: "chevron.right") }
                }
                .foregroundStyle(Theme.textPrimary)
                Spacer()
                GlassSegmented(options: PeriodScope.allCases, selection: $scope) { $0.rawValue }.frame(width: 160)
            }
            .padding(.top, 6)
        }
    }

    private func taxCard(periodTotal: Int) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax to set aside").foregroundStyle(Theme.textSecondary)
                    RollingAmount(cents: TaxEstimator.setAside(income: periodTotal, ratePercent: taxRate), font: .title2.bold())
                }
                Spacer()
                Text("\(taxRate.formatted(.number.precision(.fractionLength(0...1))))% of \(periodName)")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
            Text("A rough estimate at your chosen rate, not tax advice.").font(.caption).foregroundStyle(Theme.textTertiary)
        }
    }

    private func stream(_ id: UUID?) -> IncomeStream? { allStreams.first { $0.id == id } }

    private func donutCard(_ shares: [StreamShare]) -> some View {
        let focus = shares.indices.contains(donutSelection ?? -1) ? shares[donutSelection!] : shares.first
        return Card {
            Text("Income Sources").font(.sectionTitle)
            Text("Share of income by stream this \(scope == .month ? "month" : "year")")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
            if shares.isEmpty {
                ContentUnavailableView("No income in this period", systemImage: "chart.pie").frame(height: 220)
            } else {
                Chart(Array(shares.enumerated()), id: \.offset) { i, s in
                    SectorMark(angle: .value("Share", drawn ? s.total : 0),
                               innerRadius: .ratio(0.72), angularInset: 3)
                        .cornerRadius(10)
                        .foregroundStyle(stream(s.streamID)?.colorKey.color ?? StreamColor.sand.color)
                        .opacity(donutSelection == nil || donutSelection == i ? 1 : 0.35)
                }
                .chartLegend(.hidden)
                .frame(height: 230)
                .chartOverlay { _ in
                    VStack(spacing: 2) {
                        Text("\(focus?.percent ?? 0)%").font(.system(size: 34, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(stream(focus?.streamID)?.name ?? "Other").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    .animation(Motion.spring, value: focus?.percent)
                }
                .padding(.vertical, 8)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    ForEach(Array(shares.enumerated()), id: \.offset) { i, s in
                        Button { withAnimation(Motion.spring) { donutSelection = donutSelection == i ? nil : i } } label: {
                            HStack(spacing: 8) {
                                Circle().fill(stream(s.streamID)?.colorKey.color ?? StreamColor.sand.color).frame(width: 10, height: 10)
                                Text(stream(s.streamID)?.name ?? "Other").foregroundStyle(Theme.textSecondary).lineLimit(1)
                                Spacer()
                                Text("\(s.percent)%").fontWeight(.semibold).foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private func trendCard(_ agg: Aggregator, _ all: [IncomeRecord]) -> some View {
        let rs = filter.map { f in all.filter { $0.streamID == f.id } } ?? all
        let points = agg.series(rs, granularity: granularity, anchor: anchor)
        let total = points.reduce(0) { $0 + $1.total }
        let picked = scrubbed.flatMap { d in points.last { $0.start <= d } }
        let label: String = switch granularity {
        case .daily, .weekly: anchor.formatted(.dateTime.month(.abbreviated).year())
        case .monthly: rc.yearLabel(containing: anchor)
        case .yearly: "All years"
        }
        let active = streams
        return Card {
            HStack(alignment: .top) {
                StreamFilterMenu(streams: active, selection: $filter)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(picked?.label ?? label).font(.caption).foregroundStyle(Theme.textSecondary)
                    Text(Money.formatWhole(picked?.total ?? total)).font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentTint).monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Theme.accentSubtle, in: .capsule)
                }
            }
            GlassSegmented(options: Granularity.allCases, selection: $granularity) { $0.rawValue.capitalized }
            Chart(points) { p in
                AreaMark(x: .value("Period", p.start), y: .value("Income", drawn ? Double(p.total) / 100 : 0))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Theme.accentTint.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Period", p.start), y: .value("Income", drawn ? Double(p.total) / 100 : 0))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(Theme.accentTint)
                if let picked, picked.start == p.start {
                    RuleMark(x: .value("Period", p.start)).foregroundStyle(Theme.textTertiary)
                    PointMark(x: .value("Period", p.start), y: .value("Income", Double(p.total) / 100))
                        .foregroundStyle(Theme.accentTint).symbolSize(80)
                }
            }
            .chartXSelection(value: $scrubbed)
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(Theme.hairline); AxisValueLabel() } }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) { _ in AxisValueLabel(format: xFormat) } }
            .frame(height: 220)
            .animation(Motion.spring, value: granularity)
            .animation(Motion.spring, value: filter?.id)
        }
    }

    private var streams: [IncomeStream] { allStreams.filter { !$0.isArchived } }

    private var xFormat: Date.FormatStyle {
        switch granularity {
        case .daily, .weekly: .dateTime.day()
        case .monthly: .dateTime.month(.narrow)
        case .yearly: .dateTime.year(.twoDigits)
        }
    }

    private func step(_ n: Int) {
        withAnimation(Motion.spring) {
            anchor = rc.calendar.date(byAdding: scope == .month ? .month : .year, value: n, to: anchor)!
        }
    }
}
