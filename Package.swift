// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CellyKit",
    defaultLocalization: "en",
    platforms: [
        .iOS("15.0"),
    ],
    products: [
         .library(
             name: "CellyKit",
             targets: ["CellyUtils", "CellyCore", "CellyUI", "CellyCV"]
         ),
    ],
    dependencies: [
    ],
    targets: [
         .target(
             name: "CellyCV",
             dependencies: ["CellyUtils", "CellyCore"]
         ),
         .target(
             name: "CellyUtils",
             dependencies: ["CellyCore"]
         ),
        .target(
            name: "CellyCore"
        ),
         .target(
             name: "CellyUI",
             dependencies: ["CellyCore"],
             resources: [.process("Resources")]
         ),
        // .testTarget(
        //     name: "CellyCVTests",
        //     dependencies: ["CellyCV"]
        // ),
    ]
)
