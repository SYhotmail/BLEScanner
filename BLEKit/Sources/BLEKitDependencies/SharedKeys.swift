import BLEKitCore
import Foundation
import Sharing

extension SharedReaderKey where Self == AppStorageKey<FilterCriteria> {
    public static var filterCriteria: Self { .appStorage("filterCriteria") }
}

extension SharedReaderKey where Self == AppStorageKey<AppSettings> {
    public static var appSettings: Self { .appStorage("appSettings") }
}

extension SharedReaderKey where Self == AppStorageKey<[KnownBeacon]> {
    public static var knownBeacons: Self { .appStorage("knownBeacons") }
}

extension SharedReaderKey where Self == AppStorageKey<Set<UUID>> {
    public static var favoriteDeviceIdentifiers: Self { .appStorage("favoriteDeviceIdentifiers") }
}
