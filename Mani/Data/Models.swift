import Foundation
import SwiftData
import IncomeKit

// CloudKit-compatible SwiftData models: every property has a default, relationships are optional,
// no unique constraints. Enums are stored as raw strings.

@Model
final class IncomeStream {
    var id: UUID = UUID()
    var name: String = ""
    var colorRaw: String = StreamColor.burgundy.rawValue
    var iconRaw: String = StreamIcon.wallet.rawValue
    var defaultClient: String = ""
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .nullify, inverse: \IncomeEntry.stream)
    var entries: [IncomeEntry]? = []

    init(name: String, color: StreamColor, icon: StreamIcon, defaultClient: String = "", sortOrder: Int) {
        self.name = name; self.colorRaw = color.rawValue; self.iconRaw = icon.rawValue
        self.defaultClient = defaultClient; self.sortOrder = sortOrder
    }

    var colorKey: StreamColor {
        get { StreamColor(rawValue: colorRaw) ?? .burgundy }
        set { colorRaw = newValue.rawValue }
    }
    var iconKey: StreamIcon {
        get { StreamIcon(rawValue: iconRaw) ?? .wallet }
        set { iconRaw = newValue.rawValue }
    }
}

@Model
final class IncomeEntry {
    var id: UUID = UUID()
    var amountCents: Int = 0
    /// Local start-of-day for the entry's date.
    var date: Date = Date.now
    var startTime: Date?
    var endTime: Date?
    var client: String = ""
    var note: String = ""
    /// Entries created together by a repeat rule share a series id.
    var seriesID: UUID?
    var recurrenceRaw: String = Recurrence.none.rawValue
    var stream: IncomeStream?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(amountCents: Int, date: Date, stream: IncomeStream?, client: String = "", note: String = "",
         startTime: Date? = nil, endTime: Date? = nil) {
        self.amountCents = amountCents; self.date = date; self.stream = stream
        self.client = client; self.note = note; self.startTime = startTime; self.endTime = endTime
    }

    var record: IncomeRecord {
        IncomeRecord(id: id, streamID: stream?.id, amount: amountCents, date: date,
                     start: startTime, end: endTime, client: client, note: note)
    }

    /// "9:00 AM – 5:00 PM · Tom", or just the client.
    var subtitle: String {
        var parts: [String] = []
        if let s = startTime, let e = endTime {
            let f = Date.FormatStyle(date: .omitted, time: .shortened)
            parts.append("\(s.formatted(f)) – \(e.formatted(f))")
        }
        if !client.isEmpty { parts.append(client) }
        return parts.joined(separator: " · ")
    }
}
