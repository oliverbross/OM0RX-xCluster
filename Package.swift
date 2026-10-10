// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "OM0RXXCluster",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "XClusterCore", targets: ["XClusterCore"]),
        .executable(name: "om0rx-xcluster", targets: ["XClusterApp"]),
    ],
    targets: [
        .target(
            name: "XClusterCore",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("Network"),
                .linkedFramework("Security"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "XClusterApp",
            dependencies: ["XClusterCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(name: "XClusterCoreTests", dependencies: ["XClusterCore"]),
    ]
)
