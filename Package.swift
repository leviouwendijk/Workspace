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
        .package(
            url: "https://github.com/leviouwendijk/IO.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Writers.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Schema.git",
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
                .product(
                    name: "IO",
                    package: "IO"
                ),
                .product(
                    name: "Writers",
                    package: "Writers"
                ),
                .product(
                    name: "Schema",
                    package: "Schema"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
