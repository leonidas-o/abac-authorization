// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "abac-authorization",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ABACAuthorization", targets: ["ABACAuthorization"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.3.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "ABACAuthorization",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Vapor", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ABACAuthorizationTests",
            dependencies: [
                .target(name: "ABACAuthorization"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny")
] }
