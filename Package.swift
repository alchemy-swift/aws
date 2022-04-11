// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "alchemy-aws",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "AlchemyS3", targets: ["AlchemyS3"]),
    ],
    dependencies: [
        .package(url: "https://github.com/alchemy-swift/alchemy", .branch("aws")),
        .package(url: "https://github.com/soto-project/soto.git", from: "5.0.0"),
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
