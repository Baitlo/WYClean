// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WYClean",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "WYClean", targets: ["WYClean"])
    ],
    targets: [
        .target(
            name: "WYClean",
            path: "Sources"
        ),
        .testTarget(
            name: "WYCleanTests",
            dependencies: ["WYClean"],
            path: "Tests"
        )
    ]
)
