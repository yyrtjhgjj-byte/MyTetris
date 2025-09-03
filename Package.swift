// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MyTetris", // あなたのリポジトリ名に合わせて変えてもOK
    platforms: [.macOS(.v12), .iOS(.v15)], // ネイティブ用の設定（今回は使わない）
    dependencies: [
        .package(url: "https://github.com/TokamakUI/Tokamak", from: "0.11.0")
    ],
    targets: [
        .executableTarget(
            name: "MyTetris", // 上のnameと同じ名前にする
            dependencies: [
                .product(name: "TokamakShim", package: "Tokamak")
            ]),
    ]
)
