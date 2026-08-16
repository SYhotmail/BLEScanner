import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct RootView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(SidebarDestination.allCases) { destination in
                    Button {
                        store.send(.sidebarSelectionChanged(destination))
                    } label: {
                        Label(destination.title, systemImage: destination.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        store.sidebarSelection == destination
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                    .accessibilityIdentifier("sidebar.\(destination.rawValue)")
                }
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

    /*private var sidebarSelectionBinding: Binding<SidebarDestination?> {
        Binding(
            get: { store.sidebarSelection },
            set: { newValue in
                guard let newValue else { return }
                store.send(.sidebarSelectionChanged(newValue))
            }
        )
    } */
}
