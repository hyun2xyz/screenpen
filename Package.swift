// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ScreenPen",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ScreenPenCore", targets: ["ScreenPenCore"]),
        .executable(name: "ScreenPen", targets: ["ScreenPen"])
    ],
    targets: [
        .target(name: "ScreenPenCore"),
        .executableTarget(
            name: "ScreenPen",
            dependencies: ["ScreenPenCore"],
            resources: [
                .copy("Resources/Cursors"),
                .copy("Resources/Licenses")
            ]
        ),
        .testTarget(
            name: "ScreenPenCoreTests",
            dependencies: ["ScreenPenCore"]
        )
    ]
)
