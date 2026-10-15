import WidgetKit
import SwiftUI
import IncomeKit

struct Entry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, snap: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snap: WidgetSnapshot.load() ?? .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let snap = WidgetSnapshot.load() ?? .placeholder
        // The app reloads timelines whenever data changes; also refresh after midnight for "today".
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [Entry(date: .now, snap: snap)], policy: .after(midnight)))
    }
}

private let burgundy = Color(red: 0x8E / 255, green: 0x2A / 255, blue: 0x40 / 255)
private let rose = Color(red: 0xD9 / 255, green: 0x8A / 255, blue: 0x9B / 255)

struct ManiWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let s = entry.snap
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This \(s.monthLabel)").font(.caption).foregroundStyle(.secondary)
                Text(Money.formatWhole(s.monthCents)).font(.system(.title, design: .rounded).bold())
                    .minimumScaleFactor(0.6).lineLimit(1).contentTransition(.numericText())
                Spacer(minLength: 0)
                Text("Today").font(.caption2).foregroundStyle(.secondary)
                Text(Money.format(s.todayCents)).font(.subheadline.weight(.semibold)).foregroundStyle(rose)
                Text("\(s.yearLabel) · \(Money.formatWhole(s.yearCents))").font(.caption2).foregroundStyle(.secondary)
            }
            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming").font(.caption).foregroundStyle(.secondary)
                    if s.next.isEmpty { Text("Nothing scheduled").font(.caption).foregroundStyle(.tertiary) }
                    ForEach(s.next, id: \.self) { i in
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(i.stream).font(.caption.weight(.medium)).lineLimit(1)
                                Text(i.date.formatted(.dateTime.weekday().day())).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.formatWhole(i.cents)).font(.caption.weight(.semibold))
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [burgundy.opacity(0.45), Color(red: 0.05, green: 0.04, blue: 0.045)],
                           startPoint: .topLeading, endPoint: .bottom)
        }
    }
}

@main
struct ManiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ManiIncome", provider: Provider()) { ManiWidgetView(entry: $0) }
            .configurationDisplayName("Mani income")
            .description("This month's income, today's total and what's coming up.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
