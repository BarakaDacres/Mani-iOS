import SwiftUI
import SwiftData
import IncomeKit

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeEntry.date, order: .reverse) private var entries: [IncomeEntry]
    @Query(filter: #Predicate<IncomeStream> { !$0.isArchived }, sort: \IncomeStream.sortOrder) private var streams: [IncomeStream]
    @AppStorage(Pref.firstWeekday) private var firstWeekday = 2
    @State private var filter: IncomeStream?
    @State private var search = ""
    @State private var editing: IncomeEntry?
    @State private var undo: UndoItem?

    private var filtered: [IncomeEntry] {
        entries.filter { e in
            (filter == nil || e.stream == filter) &&
            (search.isEmpty || e.client.localizedCaseInsensitiveContains(search)
             || e.note.localizedCaseInsensitiveContains(search)
             || (e.stream?.name.localizedCaseInsensitiveContains(search) ?? false))
        }
    }

    var body: some View {
        let rc = ReportingCalendar(firstWeekday: firstWeekday)
        let byDay = Dictionary(grouping: filtered) { rc.startOfDay($0.date) }
        let days = byDay.keys.sorted(by: >)

        List {
            StreamFilterMenu(streams: streams, selection: $filter)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            ForEach(days, id: \.self) { day in
                let items = byDay[day] ?? []
                Section {
                    ForEach(items) { e in
                        EntryRow(entry: e) { remove(e) }
                            .contentShape(.rect)
                            .onTapGesture { editing = e }
                            .swipeActions { Button("Delete", systemImage: "trash", role: .destructive) { remove(e) } }
                            .listRowBackground(Theme.cardTop)
                    }
                } header: {
                    HStack(spacing: 10) {
                        Text(day.formatted(.dateTime.day().month(.abbreviated).year()))
                            .font(.headline).foregroundStyle(Theme.textPrimary)
                        StatusBadge(status: rc.status(of: day))
                        Spacer()
                        Text(Money.format(items.reduce(0) { $0 + $1.amountCents }))
                            .font(.subheadline).foregroundStyle(Theme.textSecondary).monospacedDigit()
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .scrollContentBackground(.hidden)
        .background(ManiBackground())
        .animation(Motion.spring, value: filtered.map(\.id))
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView("No income yet", systemImage: "clock", description: Text("Tap + to add your first entry."))
            }
        }
        .searchable(text: $search, prompt: "Client, note or stream")
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: CSVFile(text: DataService(context: context).csv()),
                              preview: SharePreview("Mani income.csv")) { Label("Export CSV", systemImage: "square.and.arrow.up") }
                } label: { Image(systemName: "ellipsis") }
            }
        }
        .sheet(item: $editing) { AddIncomeSheet(editing: $0) }
        .overlay(alignment: .bottom) {
            if let undo {
                HStack {
                    Text("Entry deleted").foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button("Undo") { restore(undo) }.fontWeight(.semibold).foregroundStyle(Theme.accentTint)
                }
                .padding(.horizontal, 20).frame(height: 52)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal, Theme.screenPadding).padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: undo.id) {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(Motion.spring) { if self.undo?.id == undo.id { self.undo = nil } }
                }
            }
        }
    }

    private func remove(_ e: IncomeEntry) {
        let item = UndoItem(e)
        DataService(context: context).delete(e)
        withAnimation(Motion.spring) { undo = item }
    }

    private func restore(_ u: UndoItem) {
        let e = IncomeEntry(amountCents: u.amount, date: u.date, stream: u.stream, client: u.client, note: u.note,
                            startTime: u.start, endTime: u.end)
        e.seriesID = u.seriesID; e.recurrenceRaw = u.recurrenceRaw
        context.insert(e)
        DataService(context: context).commit()
        withAnimation(Motion.spring) { undo = nil }
    }
}

struct UndoItem: Identifiable {
    let id = UUID()
    let amount: Int, date: Date, start: Date?, end: Date?, client: String, note: String
    let stream: IncomeStream?, seriesID: UUID?, recurrenceRaw: String
    init(_ e: IncomeEntry) {
        amount = e.amountCents; date = e.date; start = e.startTime; end = e.endTime
        client = e.client; note = e.note; stream = e.stream; seriesID = e.seriesID; recurrenceRaw = e.recurrenceRaw
    }
}

/// CSV wrapped as a Transferable file for ShareLink.
struct CSVFile: Transferable {
    let text: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mani income.csv")
            try Data(file.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
