import BLEKitCore
import Dependencies
import DependenciesMacros
import Foundation
import SwiftData

@DependencyClient
public struct HistoryClient: Sendable {
    public var upsert: @Sendable (HistoryRecordDTO) async throws -> Void
    public var fetchAll: @Sendable () async throws -> [HistoryRecordDTO] = { [] }
    public var delete: @Sendable (String) async throws -> Void
    public var deleteAll: @Sendable () async throws -> Void
}

extension HistoryClient: DependencyKey {
    public static let liveValue: HistoryClient = {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: HistoryRecord.self)
        } catch {
            // Falls back to an in-memory store rather than crashing if on-disk creation fails.
            container = try! ModelContainer(
                for: HistoryRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        let actor = HistoryModelActor(modelContainer: container)
        return HistoryClient(
            upsert: { try await actor.upsert($0) },
            fetchAll: { try await actor.fetchAll() },
            delete: { try await actor.delete(identifier: $0) },
            deleteAll: { try await actor.deleteAll() }
        )
    }()

    public static let testValue = HistoryClient()
}

extension DependencyValues {
    public var history: HistoryClient {
        get { self[HistoryClient.self] }
        set { self[HistoryClient.self] = newValue }
    }
}
