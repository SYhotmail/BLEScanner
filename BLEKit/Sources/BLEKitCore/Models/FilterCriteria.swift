import Foundation

public struct FilterCriteria: Equatable, Sendable, Codable {
    public var isNameFilterEnabled: Bool
    public var nameQuery: String
    public var isIdentifierFilterEnabled: Bool
    public var identifierQuery: String
    public var isRSSIFilterEnabled: Bool
    public var minimumRSSI: Int

    public init(
        isNameFilterEnabled: Bool = false,
        nameQuery: String = "",
        isIdentifierFilterEnabled: Bool = false,
        identifierQuery: String = "",
        isRSSIFilterEnabled: Bool = false,
        minimumRSSI: Int = -100
    ) {
        self.isNameFilterEnabled = isNameFilterEnabled
        self.nameQuery = nameQuery
        self.isIdentifierFilterEnabled = isIdentifierFilterEnabled
        self.identifierQuery = identifierQuery
        self.isRSSIFilterEnabled = isRSSIFilterEnabled
        self.minimumRSSI = minimumRSSI
    }

    public static let `default` = FilterCriteria()
}
