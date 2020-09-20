// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "abac-authorization",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "ABACAuthorization", targets: ["ABACAuthorization"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.3.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "ABACAuthorization", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Vapor", package: "vapor"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(name: "ABACAuthorizationTests", dependencies: [
            .target(name: "ABACAuthorization"),
            .product(name: "XCTVapor", package: "vapor"),
        ]),
    ]
)
