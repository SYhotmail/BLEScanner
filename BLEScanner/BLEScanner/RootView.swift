import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

/// A custom hamburger-triggered overlay drawer, rather than `NavigationSplitView`'s native
/// sidebar chrome. `NavigationSplitView` ties sidebar reveal/collapse on compact width to its
/// own `columnVisibility` binding in ways that proved unreliable to drive explicitly from a
/// toolbar button (the sidebar column would intermittently fail to appear). A plain overlay
/// sidesteps that entirely and behaves identically on every device size, matching the Android
/// reference app's drawer.
struct RootView: View {
    @Bindable var store: StoreOf<AppFeature>
    @State private var isSidebarOpen = false

    var body: some View {
        ZStack(alignment: .leading) {
            detailContent
                .disabled(isSidebarOpen)

            if isSidebarOpen {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { closeSidebar() }
                    .transition(.opacity)
                    .accessibilityIdentifier("sidebar.scrim")

                sidebarContent
                    .frame(maxWidth: 320)
                    .frame(maxHeight: .infinity)
                    .background(.regularMaterial)
                    .ignoresSafeArea()
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSidebarOpen)
    }

    private var detailContent: some View {
        NavigationStack {
            Group {
                switch store.sidebarSelection {
                case .scanner:
                    ScannerView(store: store.scope(state: \.scanner, action: \.scanner))
                case .filter:
                    FilterView(store: store.scope(state: \.filter, action: \.filter))
                case .settings:
                    SettingsView(store: store.scope(state: \.settings, action: \.settings))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isSidebarOpen = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityIdentifier("sidebar.hamburgerButton")
                    .accessibilityLabel("Menu")
                }
            }
        }
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BLEScanner")
                .font(.title2.bold())
                .padding()

            List(SidebarDestination.allCases) { destination in
                Button {
                    store.send(.sidebarSelectionChanged(destination))
                    closeSidebar()
                } label: {
                    Label(destination.title, systemImage: destination.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    store.sidebarSelection == destination
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .accessibilityIdentifier("sidebar.\(destination.rawValue)")
            }
            .listStyle(.plain)
        }
    }

    private func closeSidebar() {
        isSidebarOpen = false
    }
}
