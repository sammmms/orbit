// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Orbit",
            path: "Sources/Orbit"
        ),
        .testTarget(
            name: "OrbitTests",
            dependencies: ["Orbit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
