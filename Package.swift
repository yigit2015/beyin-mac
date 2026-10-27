// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Beyin",
    platforms: [
        .macOS(.v26),
    ],
    targets: [
        .target(
            name: "BeyinCore",
            path: "Sources/BeyinCore"),
        .executableTarget(
            name: "Beyin",
            dependencies: ["BeyinCore"],
            path: "Sources/Beyin"),
        .testTarget(
            name: "BeyinCoreTests",
            dependencies: ["BeyinCore"],
            path: "Tests/BeyinCoreTests",
            resources: [
                .copy("Fixtures"),
            ]),
    ]
)
