import Foundation
import SwiftData
import WidgetKit
import IncomeKit

enum StoreFactory {
    /// Local SwiftData store in the App Group. When the iCloud toggle is on, the same store
    /// mirrors to the user's private CloudKit database. The toggle applies on next launch.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([IncomeStream.self, IncomeEntry.self])
        let useCloud = UserDefaults.standard.bool(forKey: Pref.iCloudSync)
        let container = (Bundle.main.object(forInfoDictionaryKey: "ICLOUD_CONTAINER") as? String)
            ?? "iCloud.com.barakadacres.mani"
        let config = ModelConfiguration(
            "Mani", schema: schema,
            groupContainer: .identifier(WidgetSnapshot.appGroup),
            cloudKitDatabase: useCloud ? .private(container) : .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Fall back to a local-only store (e.g. iCloud not set up in the developer account).
            let local = ModelConfiguration("Mani", schema: schema, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: local)
        }
    }

    static func preview() -> ModelContainer {
        let schema = Schema([IncomeStream.self, IncomeEntry.self])
        let c = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        DataService(context: c.mainContext).seedIfNeeded(sample: true)
        return c
    }
}

/// All writes go through here so recurrence, archiving and the widget snapshot stay consistent.
struct DataService {
    let context: ModelContext

    func activeStreams() -> [IncomeStream] {
        let d = FetchDescriptor<IncomeStream>(predicate: #Predicate { !$0.isArchived },
                                              sortBy: [SortDescriptor(\.sortOrder)])
        return (try? context.fetch(d)) ?? []
    }

    func allEntries() -> [IncomeEntry] {
        (try? context.fetch(FetchDescriptor<IncomeEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
    }

    func seedIfNeeded(sample: Bool = false) {
        let count = (try? context.fetchCount(FetchDescriptor<IncomeStream>())) ?? 0
        guard count == 0 else { return }
        let streams = StreamSeed.defaults.enumerated().map { i, s in
            IncomeStream(name: s.name, color: s.color, icon: s.icon, defaultClient: s.defaultClient ?? "", sortOrder: i)
        }
        streams.forEach(context.insert)
        if sample {
            let cal = Calendar.current, today = cal.startOfDay(for: .now)
            for (offset, cents, si, client) in [(2, 80000, 0, "Glenn"), (1, 37548, 1, "Tom"), (0, 18933, 1, "Tom"),
                                                (-1, 33245, 1, "Tom"), (-2, 37500, 0, "Glenn"), (-9, 69800, 0, "Glenn")] {
                context.insert(IncomeEntry(amountCents: cents, date: cal.date(byAdding: .day, value: offset, to: today)!,
                                           stream: streams[si], client: client))
            }
        }
        try? context.save()
    }

    /// Saves a new entry, plus repeats if a rule is set. Repeats are created as concrete future entries
    /// (so they show as UPCOMING and count in totals) and share a series id for bulk delete.
    func add(amount: Int, date: Date, stream: IncomeStream?, client: String, note: String,
             start: Date?, end: Date?, recurrence: Recurrence, repeatCount: Int) {
        let cal = Calendar.current
        let first = cal.startOfDay(for: date)
        let series = recurrence == .none ? nil : UUID()
        for d in RecurrenceEngine.dates(first: first, rule: recurrence, count: repeatCount, calendar: cal) {
            let shift = cal.dateComponents([.day], from: first, to: d).day ?? 0
            let e = IncomeEntry(amountCents: amount, date: d, stream: stream, client: client, note: note,
                                startTime: start.flatMap { cal.date(byAdding: .day, value: shift, to: $0) },
                                endTime: end.flatMap { cal.date(byAdding: .day, value: shift, to: $0) })
            e.seriesID = series; e.recurrenceRaw = recurrence.rawValue
            context.insert(e)
        }
        commit()
    }

    func delete(_ entry: IncomeEntry) { context.delete(entry); commit() }

    func deleteFutureInSeries(of entry: IncomeEntry) {
        guard entry.seriesID != nil else { return delete(entry) }
        let sid: UUID? = entry.seriesID
        let from = entry.date
        let d = FetchDescriptor<IncomeEntry>(predicate: #Predicate { $0.seriesID == sid && $0.date >= from })
        (try? context.fetch(d))?.forEach(context.delete)
        commit()
    }

    /// Deleting a stream archives it: hidden from pickers, history kept.
    func archive(_ stream: IncomeStream) { stream.isArchived = true; commit() }

    func addStream() {
        let order = (activeStreams().map(\.sortOrder).max() ?? -1) + 1
        context.insert(IncomeStream(name: "New stream", color: StreamColor.allCases[order % 8], icon: .dollar, sortOrder: order))
        commit()
    }

    func move(_ stream: IncomeStream, by delta: Int) {
        var list = activeStreams()
        guard let i = list.firstIndex(of: stream) else { return }
        let j = i + delta
        guard list.indices.contains(j) else { return }
        list.swapAt(i, j)
        for (n, s) in list.enumerated() { s.sortOrder = n }
        commit()
    }

    func commit() {
        try? context.save()
        refreshWidget()
    }

    func refreshWidget() {
        let rc = ReportingCalendar.current, agg = Aggregator(rc), now = Date.now
        let entries = allEntries()
        let rs = entries.map(\.record)
        let today = DateInterval(start: rc.startOfDay(now), duration: 86400)
        let next = entries.filter { $0.date > now }.sorted { $0.date < $1.date }.prefix(3).map {
            WidgetSnapshot.Item(date: $0.date, stream: $0.stream?.name ?? "Income", client: $0.client, cents: $0.amountCents)
        }
        WidgetSnapshot(updated: now, todayCents: agg.total(rs, in: today),
                       monthCents: agg.total(rs, in: rc.monthInterval(containing: now)),
                       monthLabel: now.formatted(.dateTime.month(.abbreviated)),
                       yearCents: agg.total(rs, in: rc.yearInterval(containing: now)),
                       yearLabel: rc.yearLabel(containing: now), next: Array(next)).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func csv() -> String {
        CSVExporter.csv(allEntries().map {
            .init(date: $0.date, start: $0.startTime, end: $0.endTime, stream: $0.stream?.name ?? "",
                  client: $0.client, amount: $0.amountCents, note: $0.note)
        })
    }
}
