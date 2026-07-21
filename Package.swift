// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lockin",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Lockin",
            path: "Sources/Lockin"
        )
    ]
)
