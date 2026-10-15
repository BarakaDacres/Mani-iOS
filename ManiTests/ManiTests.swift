import Testing
import Foundation
import SwiftData
import IncomeKit
@testable import Mani

@MainActor
@Suite struct DataServiceTests {
    func makeService() throws -> DataService {
        let schema = Schema([IncomeStream.self, IncomeEntry.self])
        let c = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let s = DataService(context: c.mainContext)
        s.seedIfNeeded()
        return s
    }

    @Test func seedsFiveStreams() throws {
        #expect(try makeService().activeStreams().map(\.name) ==
                ["Support Work", "Employment", "Side Hustle", "Investments", "Other"])
    }

    @Test func fortnightlyRepeatsCreateUpcomingEntries() throws {
        let s = try makeService()
        s.add(amount: 80000, date: .now, stream: s.activeStreams()[0], client: "Glenn", note: "",
              start: nil, end: nil, recurrence: .fortnightly, repeatCount: 4)
        let all = s.allEntries()
        #expect(all.count == 4)
        #expect(Set(all.compactMap(\.seriesID)).count == 1)
        s.deleteFutureInSeries(of: all.sorted { $0.date < $1.date }[1])
        #expect(s.allEntries().count == 1)
    }

    @Test func archivingKeepsEntries() throws {
        let s = try makeService()
        let st = s.activeStreams()[1]
        s.add(amount: 100, date: .now, stream: st, client: "", note: "", start: nil, end: nil, recurrence: .none, repeatCount: 1)
        s.archive(st)
        #expect(s.activeStreams().count == 4)
        #expect(s.allEntries().first?.stream?.name == "Employment")
    }

    @Test func reorder() throws {
        let s = try makeService()
        s.move(s.activeStreams()[0], by: 1)
        #expect(s.activeStreams().first?.name == "Employment")
    }
}
