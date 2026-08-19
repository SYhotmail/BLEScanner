import Dependencies
import DependenciesMacros

#if canImport(UIKit)
import UIKit
#endif

@DependencyClient
public struct PasteboardClient: Sendable {
    public var setString: @Sendable (String) -> Void
}

extension PasteboardClient: DependencyKey {
    public static let liveValue: PasteboardClient = {
        #if canImport(UIKit)
        return PasteboardClient(setString: { UIPasteboard.general.string = $0 })
        #else
        // `swift build`/`swift test` also compile this package for macOS (see BLEKit's
        // `platforms:`), which has no `UIPasteboard`. The app only ever runs on iOS, where the
        // `canImport(UIKit)` branch above is always the one taken.
        return PasteboardClient(setString: { _ in })
        #endif
    }()

    public static let testValue = PasteboardClient()
}

extension DependencyValues {
    public var pasteboard: PasteboardClient {
        get { self[PasteboardClient.self] }
        set { self[PasteboardClient.self] = newValue }
    }
}
