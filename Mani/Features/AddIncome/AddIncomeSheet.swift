import SwiftUI
import SwiftData
import IncomeKit

/// Add / edit income. Layout matches the prototype: big centred amount, stream chip grid,
/// date, start + end side by side, client (prefilled from stream default), note, Save.
struct AddIncomeSheet: View {
    var editing: IncomeEntry? = nil
    var initialDate: Date = .now

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<IncomeStream> { !$0.isArchived }, sort: \IncomeStream.sortOrder) private var streams: [IncomeStream]
    @AppStorage(Pref.hourlyRate) private var defaultRateCents = 0

    @State private var amountText = ""
    @State private var stream: IncomeStream?
    @State private var date = Date.now
    @State private var start: Date?
    @State private var end: Date?
    @State private var client = ""
    @State private var note = ""
    @State private var recurrence: Recurrence = .none
    @State private var repeatCount = 8
    @State private var rateText = ""
    @State private var saved = 0
    @FocusState private var amountFocused: Bool

    private var cents: Int? { Money.cents(from: amountText) }
    private var minutes: Int? {
        guard let start, let end else { return nil }
        return TimeRange.minutes(start: start, end: end, calendar: .current)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    amountField.padding(.vertical, 8)
                    streamGrid
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden().frame(maxWidth: .infinity, alignment: .leading).fieldStyle()
                    HStack(spacing: 10) {
                        TimeField(placeholder: "Start", value: $start)
                        TimeField(placeholder: "End", value: $end)
                    }
                    if let minutes { rateHelper(minutes) }
                    TextField("Client / source", text: $client).textContentType(.name).fieldStyle()
                    TextField("Note", text: $note, axis: .vertical).lineLimit(1...3).fieldStyle()
                    if editing == nil { repeatRow }
                    PrimaryGlassButton(title: editing == nil ? "Save income" : "Save changes",
                                       enabled: (cents ?? 0) > 0, action: save)
                        .padding(.top, 6)
                    if let editing {
                        Button("Delete entry", role: .destructive) {
                            DataService(context: context).delete(editing); dismiss()
                        }
                        .foregroundStyle(Theme.destructive)
                        if editing.seriesID != nil {
                            Button("Delete this and later repeats", role: .destructive) {
                                DataService(context: context).deleteFutureInSeries(of: editing); dismiss()
                            }
                            .font(.footnote).foregroundStyle(Theme.destructive)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(editing == nil ? "Add Income" : "Edit Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.bgBase)
        .sensoryFeedback(.success, trigger: saved)
        .onAppear(perform: load)
    }

    private var amountField: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("$").font(.system(size: 32, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textSecondary)
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize()
                .focused($amountFocused)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture { amountFocused = true }
    }

    private var streamGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(streams) { s in
                let selected = s == stream
                Button {
                    withAnimation(Motion.snappy) { selectStream(s) }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: s.iconKey.systemImage).font(.system(size: 17))
                        Text(s.name).font(.footnote.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selected ? s.colorKey.color : Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .background(selected ? s.colorKey.color.opacity(0.16) : Theme.elevated, in: .rect(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(selected ? s.colorKey.color : Theme.hairline, lineWidth: selected ? 1.5 : 1))
                }
                .buttonStyle(PressScaleStyle())
                .sensoryFeedback(.selection, trigger: selected)
            }
        }
    }

    private func rateHelper(_ minutes: Int) -> some View {
        let rate = Money.cents(from: rateText) ?? 0
        let calc = TimeRange.amount(minutes: minutes, ratePerHour: rate)
        let hours = Double(minutes) / 60
        return HStack(spacing: 8) {
            Text(hours.formatted(.number.precision(.fractionLength(0...2))) + " h ×")
                .foregroundStyle(Theme.textSecondary)
            TextField("Rate/hr", text: $rateText).keyboardType(.decimalPad).frame(width: 80)
            Spacer()
            Button("Use \(Money.format(calc))") {
                amountText = String(format: "%.2f", Double(calc) / 100)
                if rate > 0 { defaultRateCents = rate }
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentTint)
            .disabled(calc == 0)
        }
        .font(.subheadline)
        .fieldStyle()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var repeatRow: some View {
        HStack {
            Image(systemName: "repeat").foregroundStyle(Theme.textSecondary)
            Picker("Repeat", selection: $recurrence) {
                Text("Doesn't repeat").tag(Recurrence.none)
                Text("Weekly").tag(Recurrence.weekly)
                Text("Fortnightly").tag(Recurrence.fortnightly)
                Text("Monthly").tag(Recurrence.monthly)
            }
            .labelsHidden()
            Spacer()
            if recurrence != .none {
                Stepper("\(repeatCount)×", value: $repeatCount, in: 2...52).fixedSize()
            }
        }
        .fieldStyle()
    }

    private func selectStream(_ s: IncomeStream) {
        // Prefill client with the stream's default unless the user already typed a different one.
        let previousDefault = stream?.defaultClient ?? ""
        stream = s
        if client.isEmpty || client == previousDefault { client = s.defaultClient }
    }

    private func load() {
        if rateText.isEmpty, defaultRateCents > 0 { rateText = String(format: "%.2f", Double(defaultRateCents) / 100) }
        if let e = editing {
            amountText = String(format: "%.2f", Double(e.amountCents) / 100)
            stream = e.stream; date = e.date; start = e.startTime; end = e.endTime
            client = e.client; note = e.note
        } else {
            date = initialDate
            if stream == nil, let first = streams.first { selectStream(first) }
            amountFocused = true
        }
    }

    private func save() {
        guard let cents, cents > 0 else { return }
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        // Anchor times to the chosen date; an end before the start rolls to the next day.
        func anchor(_ t: Date?) -> Date? {
            guard let t else { return nil }
            let c = cal.dateComponents([.hour, .minute], from: t)
            return cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: day)
        }
        let s = anchor(start)
        var e = anchor(end)
        if let s0 = s, let e0 = e, e0 <= s0 { e = cal.date(byAdding: .day, value: 1, to: e0) }

        if let entry = editing {
            entry.amountCents = cents; entry.stream = stream; entry.date = day
            entry.startTime = s; entry.endTime = e; entry.client = client; entry.note = note
            entry.updatedAt = .now
            DataService(context: context).commit()
        } else {
            DataService(context: context).add(amount: cents, date: day, stream: stream, client: client, note: note,
                                              start: s, end: e, recurrence: recurrence, repeatCount: repeatCount)
        }
        saved += 1
        dismiss()
    }
}

/// Capsule time field that's empty until tapped (times are optional).
struct TimeField: View {
    let placeholder: String
    @Binding var value: Date?
    var body: some View {
        HStack {
            if let v = value {
                DatePicker(placeholder, selection: Binding(get: { v }, set: { value = $0 }), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer(minLength: 0)
                Button { withAnimation(Motion.snappy) { value = nil } } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear \(placeholder)")
            } else {
                Button {
                    withAnimation(Motion.snappy) {
                        let cal = Calendar.current
                        value = cal.date(bySettingHour: placeholder == "Start" ? 9 : 17, minute: 0, second: 0, of: .now)
                    }
                } label: {
                    Text(placeholder).foregroundStyle(Theme.textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .fieldStyle()
    }
}
