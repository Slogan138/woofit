// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WoofitCore",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        // 앱 타겟은 iOS·watchOS 뿐이지만, macOS 를 넣어두면
        // 시뮬레이터 없이 `swift test` 로 도메인 로직을 검증할 수 있다.
        .macOS(.v26)
    ],
    products: [
        .library(name: "WoofitCore", targets: ["WoofitCore"])
    ],
    targets: [
        .target(name: "WoofitCore"),
        .testTarget(name: "WoofitCoreTests", dependencies: ["WoofitCore"])
    ]
)
