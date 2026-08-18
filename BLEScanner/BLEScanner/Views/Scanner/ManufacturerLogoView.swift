import BLEKitCore
import SwiftUI
import UIKit

/// Monochrome manufacturer badge shown under a device row's RSSI circle. Apple uses the
/// system `apple.logo` SF Symbol. Every other manufacturer prefers a template image from
/// `Assets.xcassets` (asset name `logo-<manufacturer>`) when one has been supplied there, and
/// falls back to a plain letter-monogram placeholder otherwise — deliberately generic (no
/// brand styling/colors) rather than an approximation of the real trademark, since this repo
/// doesn't have rights to reproduce third-party company logos.
struct ManufacturerLogoView: View {
    let manufacturer: Manufacturer
    var maxLogoHeight: CGFloat?
    
    var body: some View {
        Group {
            if let logoImage {
                logoImage
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: maxLogoHeight)
            } else {
                Text(manufacturer.displayName)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel(manufacturer.displayName)
    }

    private var logoImage: Image? {
        switch manufacturer {
        case .apple:
            return Image(systemName: "apple.logo")
        case .microsoft, .google:
            let assetName = "logo-\(manufacturer.rawValue)"
            guard UIImage(named: assetName) != nil else { return nil }
            return Image(assetName)
        case .samsung, .amazon, .sony:
            return nil
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(Manufacturer.allCases, id: \.self) { manufacturer in
            ManufacturerLogoView(manufacturer: manufacturer)
                .frame(height: 50)
        }
    }
    .frame(width: 200)
}
