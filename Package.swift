// swift-tools-version:5.9
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "StorageKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .macCatalyst(.v13),
        .visionOS(.v1),
        .tvOS(.v13),
        .watchOS(.v6)
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
                    .copy("../PrivacyInfo.xcprivacy")
                ]),
        .testTarget(name: "StorageKitTests",
                    dependencies: [
                        "StorageKit"
                    ],
                    path: "Tests")
    ]
)
