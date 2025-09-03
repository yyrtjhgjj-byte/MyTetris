// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MyTetris",
    platforms: [.macOS(.v12), .iOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/TokamakUI/Tokamak", from: "0.11.0"),
        // ▼▼▼ この行をここに追加 ▼▼▼
        .package(url: "https://github.com/swiftwasm/carton", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MyTetris",
            dependencies: [
                .product(name: "TokamakShim", package: "Tokamak")
            ]),
    ]
)
