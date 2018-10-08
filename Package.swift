// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FantasyML",
    dependencies: [
        .package(url: "https://github.com/yaslab/CSV.swift.git", .upToNextMinor(from: "2.2.1")),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "1.5.10"),
    ],
    targets: [
        .target(
            name: "FantasyML",
            dependencies: ["CSV", "SwiftSoup"]),
    ]
)
