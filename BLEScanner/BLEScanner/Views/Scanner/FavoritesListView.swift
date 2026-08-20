import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

/// Lists connectable devices the user has starred via long press on the Nearby tab. Reuses
/// `ScannerDeviceRow`, so a row here can be un-starred the same way it was starred — long press
/// toggles the favorite off. A device only appears here while it's also currently in range (see
/// `ScannerFeature.State.favoriteSortedDevices`).
struct FavoritesListView: View {
    let store: StoreOf<ScannerFeature>

    var body: some View {
        let devices = store.favoriteSortedDevices
        List {
            ForEach(devices) { device in
                ScannerDeviceRow(store: store, device: device)
            }
        }
        .listStyle(.plain)
        .overlay {
            if devices.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Long-press a connectable device on the Nearby tab to add it here.")
                )
            }
        }
    }
}
