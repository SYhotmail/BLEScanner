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
                    .transition(.move(edge: .leading))
                    // Lets the drawer be dismissed the way the Android reference drawer (and every
                    // other iOS drawer) is: a leftward drag anywhere on it, not just a tap outside.
                    // `simultaneousGesture` (rather than `gesture`) so this never steals touches
                    // from the List's own vertical scroll recognizer; the width-vs-height check
                    // additionally ignores drags that are mostly vertical scrolling.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                if value.translation.width < -40,
                                   abs(value.translation.width) > abs(value.translation.height) {
                                    closeSidebar()
                                }
                            }
                    )
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

    /// Its own `NavigationStack` with a matching, un-overridden `.navigationTitle` — rather than
    /// a manually-positioned `Text` — so "BLE Scanner" renders through the same system nav-bar
    /// chrome as "Scanner"/"Filter"/"Settings" and lines up with it exactly, at any Dynamic Type
    /// size or display mode, instead of needing hand-tuned padding to approximate it.
    private var sidebarContent: some View {
        NavigationStack {
            List(SidebarDestination.allCases) { destination in
                Button {
                    store.send(.sidebarSelectionChanged(destination))
                    // Deferred to the next run loop turn rather than called inline here: bundling
                    // a TCA `store.send` (which invalidates observation and re-renders the scoped
                    // child) and this plain `@State` mutation into the same synchronous closure
                    // occasionally dropped the `@State` change on device, leaving the drawer stuck
                    // open even though navigation had already switched underneath it.
                    DispatchQueue.main.async { closeSidebar() }
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
            .navigationTitle("BLE Scanner")
        }
    }

    private func closeSidebar() {
        isSidebarOpen = false
    }
}
