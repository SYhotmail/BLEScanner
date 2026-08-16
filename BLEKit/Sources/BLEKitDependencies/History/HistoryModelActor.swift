import BLEKitCore
import Foundation
import SwiftData

/// Owns the SwiftData `ModelContainer`/`ModelContext` for scan history and returns/accepts only
/// `Sendable` DTOs, since `@Model` types cannot cross actor boundaries under strict concurrency.
@ModelActor
public actor HistoryModelActor {
    public func upsert(_ dto: HistoryRecordDTO) throws {
        let identifier = dto.identifier
        let descriptor = FetchDescriptor<HistoryRecord>(predicate: #Predicate { $0.identifier == identifier })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = dto.name
            existing.lastRSSI = dto.lastRSSI
            existing.lastSeenDate = dto.lastSeenDate
        } else {
            modelContext.insert(
                HistoryRecord(
                    identifier: dto.identifier,
                    name: dto.name,
                    lastRSSI: dto.lastRSSI,
                    lastSeenDate: dto.lastSeenDate,
                    firstSeenDate: dto.firstSeenDate
                )
            )
        }
        try modelContext.save()
    }

    public func fetchAll() throws -> [HistoryRecordDTO] {
        let descriptor = FetchDescriptor<HistoryRecord>(sortBy: [SortDescriptor(\.lastSeenDate, order: .reverse)])
        return try modelContext.fetch(descriptor).map(HistoryRecordDTO.init)
    }

    public func delete(identifier: String) throws {
        let descriptor = FetchDescriptor<HistoryRecord>(predicate: #Predicate { $0.identifier == identifier })
        for record in try modelContext.fetch(descriptor) {
            modelContext.delete(record)
        }
        try modelContext.save()
    }
}

extension HistoryRecordDTO {
    init(_ record: HistoryRecord) {
        self.init(
            identifier: record.identifier,
            name: record.name,
            lastRSSI: record.lastRSSI,
            lastSeenDate: record.lastSeenDate,
            firstSeenDate: record.firstSeenDate
        )
    }
}
