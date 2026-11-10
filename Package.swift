// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AulaF75Driver",
    defaultLocalization: "de",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AulaCore", targets: ["AulaCore"]),
        .executable(name: "AulaF75Driver", targets: ["AulaF75Driver"])
    ],
    targets: [
        .target(
            name: "AulaCore"
        ),
        .executableTarget(
            name: "AulaF75Driver",
            dependencies: ["AulaCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "AulaCoreTests",
            dependencies: ["AulaCore"]
        )
    ]
)
