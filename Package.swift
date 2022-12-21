// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HackerNewsKit",
    platforms: [
        .iOS("16.0"),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "HackerNewsKit",
            targets: ["HackerNewsKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "9.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.0.0"),
        .package(url: "https://github.com/malcommac/SwiftScanner.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.0.3")
    ],
    targets: [
        .target(
            name: "HackerNewsKit",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                "SwiftSoup",
                "SwiftScanner"
            ]),
        .testTarget(
            name: "HackerNewsKitTests",
            dependencies: ["HackerNewsKit"]),
    ]
)
