// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AtlasCore",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "AtlasCore",
            targets: ["AtlasCore"]
        ),
        ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/powderhouse/iam.git", .exact("0.0.4")),
        .package(url: "https://github.com/powderhouse/s3.git", .exact("0.0.3")),
        .package(url: "https://github.com/Quick/Quick.git", from: "1.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "7.1.0"),
        ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "AtlasCore",
            dependencies: ["SwiftAWSIam", "SwiftAWSS3"]),
        .testTarget(
            name: "AtlasCoreTests",
            dependencies: ["AtlasCore", "Quick", "Nimble"]),
        ]
)


// GENERATE: swift package generate-xcodeproj --xcconfig-overrides settings.xcconfig
// LOCAL STACK: sudo SERVICES=s3 localstack start
