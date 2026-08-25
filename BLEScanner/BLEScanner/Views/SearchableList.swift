import ComposableArchitecture
import SwiftUI

/// Shared search + empty-state chrome for the Near By, Favorites, and History lists: a
/// `.searchable` field filtering `items` via `matches`, falling back to
/// `ContentUnavailableView.search(text:)` when a query yields no matches and to a
/// caller-supplied placeholder when the list is simply empty (no query typed). Generic over the
/// row/item type only — no dependency on any particular reducer's `Action`/`State`, just
/// `IdentifiedArrayOf` (from `ComposableArchitecture`, re-exporting `IdentifiedCollections`)
/// since that's what every call site's reducer already hands its view.
struct SearchableList<Item: Identifiable, RowContent: View, EmptyContent: View>: View {
    let items: IdentifiedArrayOf<Item>
    let matches: (Item, String) -> Bool
    @Binding var searchText: String
    // `.searchable`'s scroll-to-hide behavior piggybacks on the large-title collapse animation,
    // which doesn't reliably fire here (the segmented tab Picker above swaps the scrolling List
    // in and out). An explicit toggle sidesteps that entirely and is deterministic regardless of
    // scroll position or content length. Owned by the caller (not local `@State`) so it survives
    // this view being torn down and recreated when the caller's own containing tab switches.
    @Binding var isSearchPresented: Bool
    var searchPrompt = "Search by name or ID"
    var isLoading = false
    @ViewBuilder let row: (Item) -> RowContent
    @ViewBuilder let emptyContent: () -> EmptyContent

    private var filteredItems: [Item] {
        items.filter { matches($0, searchText) }
    }

    var body: some View {
        List(filteredItems) {
            row($0)
        }
        .listStyle(.plain)
        .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: searchPrompt)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSearchPresented.toggle()
                } label: {
                    Image(systemName: isSearchPresented ? "xmark.circle" : "magnifyingglass")
                }
                .accessibilityIdentifier("searchableList.searchToggleButton")
                .accessibilityLabel(isSearchPresented ? "Hide Search" : "Show Search")
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            } else if filteredItems.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    emptyContent()
                }
            }
        }
    }
}
