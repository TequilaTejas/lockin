// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Anchor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Anchor",
            path: "Sources/Anchor"
        )
    ]
)
