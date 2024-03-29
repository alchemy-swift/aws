// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "alchemy-aws",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AlchemyS3", targets: ["AlchemyS3"]),
    ],
    dependencies: [
        .package(url: "https://github.com/alchemy-swift/alchemy", branch: "main"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "AlchemyS3",
            dependencies: [
                .product(name: "Alchemy", package: "alchemy"),
                .product(name: "SotoS3", package: "soto"),
            ]),
    ]
)
