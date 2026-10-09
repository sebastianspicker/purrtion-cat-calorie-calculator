// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [.library(name: "PurrtionCore", targets: ["PurrtionCore"])]
var targets: [Target] = [
    .target(name: "PurrtionCore", path: "packages/swift-core/Sources/PurrtionCore",
            resources: [.process("Resources")]),
    .testTarget(name: "PurrtionCoreTests", dependencies: ["PurrtionCore"],
                path: "packages/swift-core/Tests/PurrtionCoreTests", resources: [.process("Resources")]),
]
#if os(macOS)
products.append(.executable(name: "Purrtion", targets: ["Purrtion"]))
targets.append(.executableTarget(name: "Purrtion", dependencies: ["PurrtionCore"], path: "apps/macos/Sources"))
#endif
let package = Package(name: "Purrtion", platforms: [.macOS(.v14)], products: products, targets: targets)
