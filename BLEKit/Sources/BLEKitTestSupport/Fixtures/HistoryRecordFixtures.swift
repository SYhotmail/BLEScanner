import BLEKitCore
import Foundation

public enum HistoryRecordFixtures {
    public static let recent = HistoryRecordDTO(
        identifier: "11111111-1111-1111-1111-111111111111",
        name: "Living Room Sensor",
        lastRSSI: -55,
        lastSeenDate: Date(timeIntervalSince1970: 1_700_000_100)
    )

    public static let older = HistoryRecordDTO(
        identifier: "22222222-2222-2222-2222-222222222222",
        name: "Garage Sensor",
        lastRSSI: -88,
        lastSeenDate: Date(timeIntervalSince1970: 1_700_000_000)
    )

    public static let all: [HistoryRecordDTO] = [recent, older]
}
