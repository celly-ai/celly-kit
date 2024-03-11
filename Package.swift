// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CellyCV",
    platforms: [
        .macOS(.v10_15),
        .iOS("15.0"),
    ],
    products: [
        .library(
            name: "CellyCV",
            targets: ["CellyCV"]),
    ],
    dependencies: [
        .package(path: "CellyUtilities"),
        .package(path: "CellyCore"),
    ],
    targets: [
        .target(
            name: "CellyCV",
            dependencies: [.product(name: "CellyUtils", package: "CellyUtilities"),  "CellyCore"]
        ),
        .testTarget(
            name: "CellyCVTests",
            dependencies: ["CellyCV"]),
    ]
)
