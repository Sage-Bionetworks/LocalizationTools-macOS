// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FileTranslator",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.15.0"),
        .package(url: "https://github.com/Sage-Bionetworks/JsonModel-Swift.git", from: "2.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "FileTranslator",
            dependencies: [
                .product(name: "XMLCoder", package: "XMLCoder"),
                .product(name: "JsonModel", package: "JsonModel-Swift"),
            ]),
        
        .testTarget(
            name: "FileTranslatorTests",
            dependencies: ["FileTranslator"],
            resources: [.process("Resources")]
        ),
    ]
)
