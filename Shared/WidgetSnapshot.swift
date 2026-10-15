import Foundation

/// Small JSON snapshot the app writes into the App Group for the widget to read.
/// (The widget doesn't open the SwiftData store, which keeps it fast and avoids CloudKit in the extension.)
nonisolated struct WidgetSnapshot: Codable, Sendable {
    var updated: Date
    var todayCents: Int
    var monthCents: Int
    var monthLabel: String
    var yearCents: Int
    var yearLabel: String
    var next: [Item]

    nonisolated struct Item: Codable, Sendable, Hashable {
        var date: Date
        var stream: String
        var client: String
        var cents: Int
    }

    static let placeholder = WidgetSnapshot(updated: .now, todayCents: 18933, monthCents: 737980,
        monthLabel: "Oct", yearCents: 3633721, yearLabel: "FY 26-27",
        next: [.init(date: .now.addingTimeInterval(86400), stream: "Support Work", client: "Glenn", cents: 80000)])

    static var appGroup: String {
        (Bundle.main.object(forInfoDictionaryKey: "APP_GROUP") as? String) ?? "group.com.barakadacres.mani"
    }

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.url else { return }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? enc.encode(self).write(to: url, options: .atomic)
    }
}
