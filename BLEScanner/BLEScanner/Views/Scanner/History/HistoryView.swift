import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct HistoryView: View {
    let store: StoreOf<HistoryFeature>
    @State private var isEraseAllConfirmationPresented = false

    var body: some View {
        List {
            ForEach(store.records) { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.name ?? "n/a".uppercased())
                        .font(.subheadline)
                    Text(record.identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Text("\(record.lastRSSI) dBm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Added \(record.firstSeenDate.formatted(date: .abbreviated, time: .shortened))")
                        Spacer()
                        Text("Last seen \(record.lastSeenDate.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.send(.deleteButtonTapped(record.id))
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("history.deleteButton.\(record.id)")
                }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: HistoryCSVDocument(csv: HistoryCSVExporter.csv(for: Array(store.records))),
                    preview: SharePreview("BLEScanner History")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityIdentifier("history.exportButton")
                .accessibilityLabel("Export History")
                .disabled(store.records.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isEraseAllConfirmationPresented = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityIdentifier("history.eraseAllButton")
                .accessibilityLabel("Erase All History")
                .disabled(store.records.isEmpty)
            }
        }
        .confirmationDialog(
            "Erase All History?",
            isPresented: $isEraseAllConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Erase All", role: .destructive) {
                store.send(.eraseAllButtonTapped)
            }
        } message: {
            Text("This permanently deletes every scan history record. This cannot be undone.")
        }
    }
}
