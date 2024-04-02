// swift-tools-version:5.9
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "NStorage",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .macCatalyst(.v13),
        .visionOS(.v1),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "NStorage", targets: ["NStorage"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "NStorage",
                dependencies: [
                ],
                path: "Source",
                resources: [
                    .copy("../PrivacyInfo.xcprivacy")
                ]),
        .testTarget(name: "NStorageTests",
                    dependencies: [
                        "NStorage"
                    ],
                    path: "Tests")
    ]
)
