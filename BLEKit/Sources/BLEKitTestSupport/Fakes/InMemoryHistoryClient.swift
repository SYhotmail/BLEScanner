import BLEKitCore
import BLEKitDependencies
import Foundation

public actor InMemoryHistoryClient {
    private var recordsByIdentifier: [String: HistoryRecordDTO]

    public init(seed: [HistoryRecordDTO] = []) {
        recordsByIdentifier = Dictionary(uniqueKeysWithValues: seed.map { ($0.identifier, $0) })
    }

    public func upsert(_ dto: HistoryRecordDTO) {
        recordsByIdentifier[dto.identifier] = dto
    }

    public func fetchAll() -> [HistoryRecordDTO] {
        recordsByIdentifier.values.sorted { $0.lastSeenDate > $1.lastSeenDate }
    }

    public func delete(identifier: String) {
        recordsByIdentifier.removeValue(forKey: identifier)
    }

    public func deleteAll() {
        recordsByIdentifier.removeAll()
    }

    public nonisolated var client: HistoryClient {
        HistoryClient(
            upsert: { await self.upsert($0) },
            fetchAll: { await self.fetchAll() },
            delete: { await self.delete(identifier: $0) },
            deleteAll: { await self.deleteAll() }
        )
    }
}
