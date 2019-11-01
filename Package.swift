// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "ABACAuthorization",
    products: [
        .library(
            name: "ABACAuthorization",
            targets: ["ABACAuthorization"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.3.1"),
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "ABACAuthorization",
            dependencies: ["FluentPostgreSQL", "Vapor"]),
        .testTarget(
            name: "ABACAuthorizationTests",
            dependencies: ["ABACAuthorization", "FluentPostgreSQL", "Vapor"]),
    ]
)
