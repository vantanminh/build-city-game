// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CityCore",
    targets: [
        .target(
            name: "CityCore"
        ),
        .testTarget(
            name: "CityCoreTests",
            dependencies: ["CityCore"]
        )
    ]
)
