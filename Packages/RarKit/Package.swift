// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RarKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "RarKit", targets: ["RarKit"]),
    ],
    targets: [
        .target(
            name: "RarKit",
            path: "Sources/RarKit"
        ),
        .testTarget(
            name: "RarKitTests",
            dependencies: ["RarKit"],
            path: "Tests/RarKitTests"
        ),
    ]
)
