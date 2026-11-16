// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CityCore",
    products: [
        .library(
            name: "CityCore",
            targets: ["CityCore"]
        )
    ],
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
