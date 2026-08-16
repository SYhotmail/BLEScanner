// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "BLEKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "BLEKitCore", targets: ["BLEKitCore"]),
        .library(name: "BLEKitHardware", targets: ["BLEKitHardware"]),
        .library(name: "BLEKitDependencies", targets: ["BLEKitDependencies"]),
        .library(name: "BLEFeatures", targets: ["BLEFeatures"]),
        .library(name: "BLEKitTestSupport", targets: ["BLEKitTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.26.0")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.9.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.9.0")),
    ],
    targets: [
        .target(
            name: "BLEKitCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "BLEKitHardware",
            dependencies: ["BLEKitCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "BLEKitDependencies",
            dependencies: [
                "BLEKitCore",
                "BLEKitHardware",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "BLEFeatures",
            dependencies: [
                "BLEKitCore",
                "BLEKitHardware",
                "BLEKitDependencies",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "BLEKitTestSupport",
            dependencies: [
                "BLEKitCore",
                "BLEKitHardware",
                "BLEKitDependencies",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BLEKitCoreTests",
            dependencies: ["BLEKitCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BLEKitDependenciesTests",
            dependencies: ["BLEKitDependencies", "BLEKitTestSupport"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BLEFeaturesTests",
            dependencies: [
                "BLEFeatures",
                "BLEKitHardware",
                "BLEKitDependencies",
                "BLEKitTestSupport",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
