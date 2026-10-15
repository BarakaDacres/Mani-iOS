import Foundation

/// Palette keys for streams. Colours themselves live in the app's design system.
public enum StreamColor: String, CaseIterable, Codable, Sendable {
    case burgundy, rose, plum, mauve, copper, sand, teal, steel
}

/// Icon keys for streams, mapped to SF Symbols.
public enum StreamIcon: String, CaseIterable, Codable, Sendable {
    case heartHand, briefcase, hardHat, building, trendUp, wallet, laptop, camera, car, gradCap, dollar

    public var systemImage: String {
        switch self {
        case .heartHand: "heart.text.square"
        case .briefcase: "briefcase"
        case .hardHat: "hammer"
        case .building: "building.2"
        case .trendUp: "chart.line.uptrend.xyaxis"
        case .wallet: "wallet.bifold"
        case .laptop: "laptopcomputer"
        case .camera: "camera"
        case .car: "car"
        case .gradCap: "graduationcap"
        case .dollar: "dollarsign.circle"
        }
    }
}

public enum YearType: String, CaseIterable, Codable, Sendable {
    case calendar, australianFY
}

public enum EntryStatus: String, Sendable {
    case upcoming, today, past
}

public enum Recurrence: String, CaseIterable, Codable, Sendable {
    case none, weekly, fortnightly, monthly
}

public enum Granularity: String, CaseIterable, Sendable {
    case daily, weekly, monthly, yearly
}

/// Seed stream definition used on first launch (matches the prototype).
public struct StreamSeed: Sendable, Equatable {
    public let name: String
    public let color: StreamColor
    public let icon: StreamIcon
    public let defaultClient: String?

    public static let defaults: [StreamSeed] = [
        .init(name: "Support Work", color: .burgundy, icon: .heartHand, defaultClient: nil),
        .init(name: "Employment", color: .teal, icon: .briefcase, defaultClient: nil),
        .init(name: "Side Hustle", color: .copper, icon: .car, defaultClient: nil),
        .init(name: "Investments", color: .plum, icon: .trendUp, defaultClient: nil),
        .init(name: "Other", color: .sand, icon: .wallet, defaultClient: nil),
    ]
}

/// Plain value used by all logic. The app maps its SwiftData models to this.
public struct IncomeRecord: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var streamID: UUID?
    public var amount: Cents
    public var date: Date
    public var start: Date?
    public var end: Date?
    public var client: String
    public var note: String

    public init(id: UUID = UUID(), streamID: UUID?, amount: Cents, date: Date,
                start: Date? = nil, end: Date? = nil, client: String = "", note: String = "") {
        self.id = id; self.streamID = streamID; self.amount = amount; self.date = date
        self.start = start; self.end = end; self.client = client; self.note = note
    }
}
