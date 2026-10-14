// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CompanionKit",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [
        .library(name: "CompanionKit", targets: ["CompanionKit"])
    ],
    dependencies: [
        .package(path: "../HubCore")
    ],
    targets: [
        .target(name: "CompanionKit", dependencies: ["HubCore"], resources: [.process("Resources")]),
        .testTarget(name: "CompanionKitTests", dependencies: ["CompanionKit", "HubCore"]),
    ]
)
