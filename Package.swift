// swift-tools-version:5.5

import PackageDescription


let package = Package(
    name: "desktop-cleanup",
    platforms: [
        .macOS(.v10_10)
    ],
    products: [
        .executable(name: "desktop-cleanup", targets: ["desktop-cleanup"])
    ],
    targets: [
        .executableTarget(name: "desktop-cleanup")
    ]
)
