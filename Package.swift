// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacKey68",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "mackey", targets: ["mackey"]),
        .library(name: "MacKeyKit", targets: ["MacKeyKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6"),
    ],
    targets: [
        .target(name: "MacKeyKit", path: "Sources/MacKeyKit"),
        .executableTarget(name: "mackey", dependencies: ["MacKeyKit"], path: "Sources/mackey"),
        .executableTarget(
            name: "MacKey68",
            dependencies: [
                "MacKeyKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/MacKey68App"
        ),
    ]
)
