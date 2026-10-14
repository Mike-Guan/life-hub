// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HubCore",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [
        .library(name: "HubCore", targets: ["HubCore"])
    ],
    targets: [
        .target(name: "HubCore", resources: [.process("Resources")]),
        .testTarget(name: "HubCoreTests", dependencies: ["HubCore"]),
    ]
)
