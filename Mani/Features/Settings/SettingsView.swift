import SwiftUI
import SwiftData
import IncomeKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(Pref.yearType) private var yearTypeRaw = YearType.australianFY.rawValue
    @AppStorage(Pref.firstWeekday) private var firstWeekday = 2
    @AppStorage(Pref.taxRate) private var taxRate = 0.0
    @AppStorage(Pref.hourlyRate) private var hourlyRate = 0
    @AppStorage(Pref.iCloudSync) private var iCloud = false
    @AppStorage(Pref.appearance) private var appearance = Appearance.dark.rawValue
    @State private var confirmWipe = false
    @State private var rateText = ""
    private let launchICloud = UserDefaults.standard.bool(forKey: Pref.iCloudSync)

    var body: some View {
        Form {
            Section("Income") {
                NavigationLink { IncomeStreamsView() } label: { Label("Income Streams", systemImage: "square.stack.3d.up") }
                Picker(selection: $yearTypeRaw) {
                    Text("Calendar year").tag(YearType.calendar.rawValue)
                    Text("Australian FY").tag(YearType.australianFY.rawValue)
                } label: { Label("Year type", systemImage: "calendar") }
                Picker(selection: $firstWeekday) {
                    ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                } label: { Label("Week starts on", systemImage: "calendar.day.timeline.left") }
            }
            Section {
                HStack {
                    Label("Tax rate", systemImage: "percent")
                    Spacer()
                    TextField("0", value: $taxRate, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60)
                    Text("%").foregroundStyle(.secondary)
                }
                HStack {
                    Label("Default hourly rate", systemImage: "clock.badge")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    TextField("0.00", text: $rateText).keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing).frame(width: 80)
                        .onChange(of: rateText) { _, v in hourlyRate = Money.cents(from: v) ?? 0 }
                }
            } header: { Text("Tax & rates") } footer: {
                Text("Stats shows how much to set aside at this rate. Set 0 to hide it. The hourly rate fills the hours × rate helper when you enter start and end times.")
            }
            Section {
                Toggle(isOn: $iCloud) { Label("iCloud sync", systemImage: "icloud") }
                if iCloud != launchICloud {
                    Text("Restart Mani to \(iCloud ? "turn on" : "turn off") iCloud sync.").font(.footnote).foregroundStyle(Theme.accentTint)
                }
                ShareLink(item: CSVFile(text: DataService(context: context).csv()), preview: SharePreview("Mani income.csv")) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) { confirmWipe = true } label: {
                    Label("Delete all entries", systemImage: "trash").foregroundStyle(Theme.destructive)
                }
            } header: { Text("Data") } footer: {
                Text("Your income stays on this iPhone. With iCloud sync on, it's also stored privately in your iCloud account.")
            }
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
        }
        .scrollContentBackground(.hidden)
        .background(ManiBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if hourlyRate > 0 { rateText = String(format: "%.2f", Double(hourlyRate) / 100) } }
        .onChange(of: yearTypeRaw) { DataService(context: context).refreshWidget() }
        .confirmationDialog("Delete every income entry?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Delete all entries", role: .destructive) {
                try? context.delete(model: IncomeEntry.self)
                DataService(context: context).commit()
            }
        } message: { Text("Streams are kept. This can't be undone.") }
    }
}

/// Rename, recolour, change icon, set default client, reorder and archive streams (prototype screen 4).
struct IncomeStreamsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<IncomeStream> { !$0.isArchived }, sort: \IncomeStream.sortOrder) private var streams: [IncomeStream]
    @Query(filter: #Predicate<IncomeStream> { $0.isArchived }, sort: \IncomeStream.name) private var archived: [IncomeStream]
    @AppStorage(Pref.yearType) private var yearTypeRaw = YearType.australianFY.rawValue
    @State private var toArchive: IncomeStream?

    var body: some View {
        let yt = YearType(rawValue: yearTypeRaw) ?? .australianFY
        ScrollView {
            VStack(spacing: Theme.gap) {
                Text("Tap a name to rename. Pick a colour or icon, reorder, or remove a stream entirely.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Card {
                    Text("Year type").font(.headline)
                    Text("Currently reporting \(ReportingCalendar(yearType: yt).yearLabel(containing: .now))")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    GlassSegmented(options: YearType.allCases,
                                   selection: Binding(get: { yt }, set: { yearTypeRaw = $0.rawValue })) {
                        $0 == .calendar ? "Calendar year" : "Australian FY"
                    }
                }
                ForEach(Array(streams.enumerated()), id: \.element.id) { i, s in
                    StreamEditor(stream: s, isFirst: i == 0, isLast: i == streams.count - 1,
                                 move: { d in withAnimation(Motion.spring) { DataService(context: context).move(s, by: d) } },
                                 remove: { toArchive = s })
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
                Button {
                    withAnimation(Motion.spring) { DataService(context: context).addStream() }
                } label: {
                    Label("Add stream", systemImage: "plus").font(.headline).foregroundStyle(Theme.accentTint)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.accentSubtle, in: .capsule)
                }
                .buttonStyle(PressScaleStyle())
                if !archived.isEmpty {
                    Card {
                        Text("Archived").font(.headline)
                        ForEach(archived) { s in
                            HStack {
                                StreamIconTile(icon: s.iconKey, color: s.colorKey, size: 36)
                                Text(s.name).foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Button("Restore") {
                                    withAnimation(Motion.spring) {
                                        s.isArchived = false
                                        s.sortOrder = (streams.map(\.sortOrder).max() ?? -1) + 1
                                        DataService(context: context).commit()
                                    }
                                }
                                .foregroundStyle(Theme.accentTint)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.bottom, 24)
        }
        .background(ManiBackground())
        .navigationTitle("Income Streams")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove \(toArchive?.name ?? "stream")?", isPresented: Binding(get: { toArchive != nil }, set: { if !$0 { toArchive = nil } }), titleVisibility: .visible) {
            Button("Remove stream", role: .destructive) {
                if let s = toArchive { withAnimation(Motion.spring) { DataService(context: context).archive(s) } }
            }
        } message: { Text("Past entries keep this stream in History and Stats. You can restore it later.") }
        .onDisappear { try? context.save() }
    }
}

struct StreamEditor: View {
    @Bindable var stream: IncomeStream
    let isFirst: Bool, isLast: Bool
    let move: (Int) -> Void
    let remove: () -> Void

    var body: some View {
        Card(padding: 20) {
            HStack(spacing: 14) {
                StreamIconTile(icon: stream.iconKey, color: stream.colorKey)
                TextField("Name", text: $stream.name).font(.headline)
                Spacer()
                Group {
                    Button { move(-1) } label: { Image(systemName: "arrow.up") }.disabled(isFirst)
                    Button { move(1) } label: { Image(systemName: "arrow.down") }.disabled(isLast)
                    Button(action: remove) { Image(systemName: "trash") }
                }
                .buttonStyle(.plain).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                ForEach(StreamColor.allCases, id: \.self) { c in
                    Button { withAnimation(Motion.snappy) { stream.colorKey = c } } label: {
                        Circle().fill(c.color).frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(Theme.textPrimary, lineWidth: stream.colorKey == c ? 2.5 : 0).padding(-3))
                    }
                    .buttonStyle(.plain).accessibilityLabel(c.rawValue.capitalized)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 6), alignment: .leading, spacing: 8) {
                ForEach(StreamIcon.allCases, id: \.self) { ic in
                    let on = stream.iconKey == ic
                    Button { withAnimation(Motion.snappy) { stream.iconKey = ic } } label: {
                        Image(systemName: ic.systemImage).font(.system(size: 16))
                            .foregroundStyle(on ? stream.colorKey.color : Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(on ? stream.colorKey.color.opacity(0.16) : Theme.elevated, in: .circle)
                            .overlay(Circle().strokeBorder(on ? stream.colorKey.color : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Default client / source").font(.subheadline).foregroundStyle(Theme.textSecondary)
            TextField("e.g. Glenn", text: $stream.defaultClient).fieldStyle()
        }
        .sensoryFeedback(.selection, trigger: stream.colorRaw + stream.iconRaw)
    }
}
