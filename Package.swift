// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Workspace",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Workspace",
            targets: [
                "Workspace",
            ]
        ),
        .executable(
            name: "worktest",
            targets: [
                "WorkspaceTests",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Path.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Position.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Selection.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Readers.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "Workspace",
            dependencies: [
                .product(
                    name: "Path",
                    package: "Path"
                ),
                .product(
                    name: "Position",
                    package: "Position"
                ),
                .product(
                    name: "Selection",
                    package: "Selection"
                ),
                .product(
                    name: "Readers",
                    package: "Readers"
                ),
            ]
        ),
        .executableTarget(
            name: "WorkspaceTests",
            dependencies: [
                "Workspace",
                .product(
                    name: "Path",
                    package: "Path"
                ),
                .product(
                    name: "Position",
                    package: "Position"
                ),
                .product(
                    name: "Selection",
                    package: "Selection"
                ),
                .product(
                    name: "Readers",
                    package: "Readers"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
