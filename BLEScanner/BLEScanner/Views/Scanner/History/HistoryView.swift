import BLEFeatures
import ComposableArchitecture
import SwiftUI

struct HistoryView: View {
    let store: StoreOf<HistoryFeature>

    var body: some View {
        List(store.records) { record in
            VStack(alignment: .leading, spacing: 2) {
                Text(record.name ?? "Unknown Device")
                    .font(.headline)
                Text(record.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack {
                    Text("\(record.lastRSSI) dBm")
                    Spacer()
                    Text(record.lastSeenDate, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.records.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock")
            }
        }
    }
}
