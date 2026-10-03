// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CompanionKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CompanionKit", targets: ["CompanionKit"]),
    ],
    dependencies: [
        .package(path: "../HubCore"),
    ],
    targets: [
        .target(
            name: "CompanionKit",
            dependencies: ["HubCore"],
            resources: [.process("Resources")]
        ),
    ]
)
