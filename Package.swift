// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "DogmaBot",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "FitAnalysis", targets: ["FitAnalysis"]),
        .executable(name: "dogma-cli", targets: ["dogma-cli"]),
        .executable(name: "DogmaBot", targets: ["DogmaBot"])
    ],
    dependencies: [
        .package(url: "https://github.com/artem-shimanski/DogmaKit.git", .upToNextMinor(from: "0.4.0")),
        .package(url: "https://github.com/DiscordBM/DiscordBM.git", .upToNextMinor(from: "1.16.2")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.100.0")
    ],
    targets: [
        // Fit text in, plain stats out. Knows nothing about Discord.
        .target(
            name: "FitAnalysis",
            dependencies: [
                .product(name: "DogmaKit", package: "DogmaKit"),
                .product(name: "DogmaKitIO", package: "DogmaKit"),
                .product(name: "DogmaText", package: "DogmaKit")
            ]
        ),
        .executableTarget(
            name: "dogma-cli",
            dependencies: ["FitAnalysis"]
        ),
        .executableTarget(
            name: "DogmaBot",
            dependencies: [
                "FitAnalysis",
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "FitAnalysisTests",
            dependencies: ["FitAnalysis"]
        ),
        .testTarget(
            name: "DogmaBotTests",
            dependencies: [
                "DogmaBot",
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "NIOCore", package: "swift-nio")
            ]
        )
    ]
)
