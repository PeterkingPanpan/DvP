// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "wasd-cursor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "wasd-cursor",
            path: "Sources"
        )
    ]
)
