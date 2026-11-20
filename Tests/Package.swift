// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "WorkspaceTests",
    platforms: [
        .macOS(.v13),
    ],
    products: [
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
        .package(
            url: "https://github.com/leviouwendijk/Writers.git",
            branch: "master"
        ),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "WorkspaceTests",
            dependencies: [
                .product(name: "Workspace", package: "Workspace"),
                .product(
                    name: "Writers",
                    package: "Writers"
                ),
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
