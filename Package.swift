// swift-tools-version:6.0
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "StorageKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .macCatalyst(.v16),
        .visionOS(.v1),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "StorageKit", targets: ["StorageKit"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "StorageKit",
                dependencies: [
                ],
                path: "Source",
                resources: [
                    .process("PrivacyInfo.xcprivacy")
                ]),
        .testTarget(name: "StorageKitTests",
                    dependencies: [
                        "StorageKit"
                    ],
                    path: "Tests")
    ]
)
