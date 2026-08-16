import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct RootView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationSplitView {
            List(SidebarDestination.allCases, selection: sidebarSelectionBinding) { destination in
                Label(destination.title, systemImage: destination.systemImage)
                    .tag(destination)
                    .accessibilityIdentifier("sidebar.\(destination.rawValue)")
            }
            .navigationTitle("BLEScanner")
        } detail: {
            switch store.sidebarSelection {
            case .scanner:
                NavigationStack {
                    ScannerView(store: store.scope(state: \.scanner, action: \.scanner))
                }
            case .filter:
                NavigationStack {
                    FilterView(store: store.scope(state: \.filter, action: \.filter))
                }
            case .settings:
                NavigationStack {
                    SettingsView(store: store.scope(state: \.settings, action: \.settings))
                }
            }
        }
    }

    /// `NavigationSplitView` needs the sidebar's own `List(selection:)` binding to drive
    /// selection — on compact width (iPhone), that binding is what makes it push from the
    /// sidebar column to the detail column when a row is tapped. Dispatching an action from a
    /// plain `Button` instead doesn't signal that to `NavigationSplitView`, so the split view
    /// never advances past the sidebar list on compact devices.
    private var sidebarSelectionBinding: Binding<SidebarDestination?> {
        Binding(
            get: { store.sidebarSelection },
            set: { newValue in
                guard let newValue else { return }
                store.send(.sidebarSelectionChanged(newValue))
            }
        )
    }
}
