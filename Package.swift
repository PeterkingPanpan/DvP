// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DvP",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DvP",
            path: "Sources"
        )
    ]
)
