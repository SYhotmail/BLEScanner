import BLEKitCore
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
