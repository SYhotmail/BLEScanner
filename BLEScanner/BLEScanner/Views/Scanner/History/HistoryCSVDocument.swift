import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Wraps CSV text produced by `HistoryCSVExporter` so it can be handed to `ShareLink` as a
/// named `.csv` file rather than shared as plain text.
struct HistoryCSVDocument: Transferable {
    let csv: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(document.csv.utf8)
        }
        .suggestedFileName("BLEScanner-History.csv")
    }
}
