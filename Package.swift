// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacKey68",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "mackey", targets: ["mackey"]),
        .library(name: "MacKeyKit", targets: ["MacKeyKit"]),
    ],
    targets: [
        .target(name: "MacKeyKit", path: "Sources/MacKeyKit"),
        .executableTarget(name: "mackey", dependencies: ["MacKeyKit"], path: "Sources/mackey"),
        .executableTarget(name: "MacKey68", dependencies: ["MacKeyKit"], path: "Sources/MacKey68App"),
    ]
)
