import BLEKitCore
import Foundation
import SwiftData
import Testing
@testable import BLEKitDependencies

@Suite("HistoryModelActor")
struct HistoryModelActorTests {
    static func makeActor() throws -> HistoryModelActor {
        let container = try ModelContainer(
            for: HistoryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return HistoryModelActor(modelContainer: container)
    }

    @Test("upserting a new identifier inserts a record")
    func upsertInsertsNewRecord() async throws {
        let actor = try Self.makeActor()
        let dto = HistoryRecordDTO(identifier: "AAA", name: "Sensor", lastRSSI: -55, lastSeenDate: .now)
        try await actor.upsert(dto)

        let all = try await actor.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.identifier == "AAA")
        #expect(all.first?.name == "Sensor")
        #expect(all.first?.lastRSSI == -55)
    }

    @Test("upserting an existing identifier updates it in place, not as a duplicate")
    func upsertUpdatesExistingRecordInPlace() async throws {
        let actor = try Self.makeActor()
        let firstSeen = Date(timeIntervalSince1970: 1_000)
        try await actor.upsert(HistoryRecordDTO(identifier: "AAA", name: "Old Name", lastRSSI: -80, lastSeenDate: firstSeen))

        let secondSeen = firstSeen.addingTimeInterval(60)
        try await actor.upsert(HistoryRecordDTO(identifier: "AAA", name: "New Name", lastRSSI: -40, lastSeenDate: secondSeen))

        let all = try await actor.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.name == "New Name")
        #expect(all.first?.lastRSSI == -40)
        #expect(all.first?.lastSeenDate == secondSeen)
        // firstSeenDate is preserved from the original insert, not overwritten by the upsert.
        #expect(all.first?.firstSeenDate == firstSeen)
    }

    @Test("fetchAll sorts by most-recently-seen first")
    func fetchAllSortsByLastSeenDescending() async throws {
        let actor = try Self.makeActor()
        let now = Date.now
        try await actor.upsert(HistoryRecordDTO(identifier: "OLD", lastRSSI: -50, lastSeenDate: now.addingTimeInterval(-100)))
        try await actor.upsert(HistoryRecordDTO(identifier: "NEW", lastRSSI: -50, lastSeenDate: now))
        try await actor.upsert(HistoryRecordDTO(identifier: "MID", lastRSSI: -50, lastSeenDate: now.addingTimeInterval(-50)))

        let all = try await actor.fetchAll()
        #expect(all.map(\.identifier) == ["NEW", "MID", "OLD"])
    }

    @Test("delete removes the record for an identifier")
    func deleteRemovesRecord() async throws {
        let actor = try Self.makeActor()
        try await actor.upsert(HistoryRecordDTO(identifier: "AAA", lastRSSI: -50, lastSeenDate: .now))
        try await actor.upsert(HistoryRecordDTO(identifier: "BBB", lastRSSI: -50, lastSeenDate: .now))

        try await actor.delete(identifier: "AAA")

        let all = try await actor.fetchAll()
        #expect(all.map(\.identifier) == ["BBB"])
    }

    @Test("deleting an unknown identifier is a no-op")
    func deleteUnknownIdentifierIsNoop() async throws {
        let actor = try Self.makeActor()
        try await actor.upsert(HistoryRecordDTO(identifier: "AAA", lastRSSI: -50, lastSeenDate: .now))

        try await actor.delete(identifier: "DOES-NOT-EXIST")

        let all = try await actor.fetchAll()
        #expect(all.count == 1)
    }
}
