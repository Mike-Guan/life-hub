// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HubCore",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [
        .library(name: "HubCore", targets: ["HubCore"])
    ],
    targets: [
        .target(name: "HubCore"),
        .testTarget(name: "HubCoreTests", dependencies: ["HubCore"]),
    ]
)
