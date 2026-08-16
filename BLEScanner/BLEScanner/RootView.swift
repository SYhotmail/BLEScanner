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
    @State var width: CGFloat = 320

    // Mirrors `store.isSidebarOpen` and is what actually drives the drawer's `.offset`/`.opacity`
    // below, rather than reading `store.isSidebarOpen` directly. Wrapping `store.send` in
    // `withAnimation` animates *opening* reliably, but TCA's `@ObservableState` publishes its
    // change to observers slightly out-of-band from the `withAnimation` call that triggered it,
    // so by the time SwiftUI notices `isSidebarOpen` went false, the transaction's animation is
    // sometimes already gone and the drawer just snaps shut. Driving the drawer off plain local
    // `@State`, mutated synchronously inside `withAnimation` at each call site, sidesteps that
    // timing gap entirely — it's the same mechanism any other SwiftUI view uses.
    //
    // The drawer and scrim are also kept unconditionally in the view tree (moved off-screen via
    // `.offset`/`.opacity` when closed, rather than an `if`-gated `.transition`), since animating
    // a property on a view that's already present is unconditionally reliable — an
    // insertion/removal `.transition` depends on SwiftUI diffing the `if` branch inside the exact
    // same transaction as the state change, which is the same fragile timing dependency as above.
    @State private var isSidebarOpen = false

    var body: some View {
        ZStack(alignment: .leading) {
            detailContent
                .disabled(isSidebarOpen)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.width
                } action: { newValue in
                    width = min(width, ceil(newValue * 0.9))
                }

            if true || isSidebarOpen { // TODO: fix me...
                Color.black
                    .opacity(isSidebarOpen ? 0.3 : 0)
                    .transition(.opacity)
                    .ignoresSafeArea()
                    .onTapGesture(perform: closeSidebar)
                    .allowsHitTesting(isSidebarOpen)
                    .accessibilityIdentifier("sidebar.scrim")
                
                sidebarContent
                    .frame(maxWidth: width)
                    .frame(maxHeight: .infinity)
                    .transition(.move(edge: .leading))
                    .offset(x: isSidebarOpen ? 0 : -width)
                    .allowsHitTesting(isSidebarOpen)
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
        .onChange(of: store.isSidebarOpen) { _, newValue in
            guard newValue != isSidebarOpen else { return }
            openSidebarWithAnimation(newValue, sendEvent: false)
        }
    }
    
    private func openSidebarWithAnimation(_ open: Bool, sendEvent: Bool = true) {
        withAnimation(.easeInOut(duration: open ? 0.25 : 0.25)) {
            isSidebarOpen = open
        }
        if sendEvent {
            store.send(open ? .sidebarOpened : .sidebarClosed)
        }
    }

    private func openSidebar() {
        openSidebarWithAnimation(true)
    }

    private func closeSidebar() {
        openSidebarWithAnimation(false)
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
                        openSidebar()
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
                    openSidebarWithAnimation(false, sendEvent: false)
                    store.send(.sidebarSelectionChanged(destination))
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
}
